#!/usr/bin/env node
// End-to-end check of the API and its access rules. Starts nothing: run it against a PocketBase
// that is already serving this repo's schema (scripts/local-e2e.sh and scripts/compose-e2e.sh
// do that for you). Runs with `node` (18+) or `bun`.
//
// Env:
//   PB_URL              default http://127.0.0.1:8090
//   PB_ADMIN_EMAIL      superuser (required)
//   PB_ADMIN_PASSWORD   superuser (required)
//   PB_APP_EMAIL        optional provisioned app login, used as user A
//   PB_APP_PASSWORD     (from initial-credentials.txt); otherwise user A is created
//   NO_HOOKS=1          the server runs WITHOUT pb_hooks: every rule must still hold
//   SHARED_PB=1         schema was imported from collections.json into an existing server:
//                       the users sign-up policy is that server's own, so it is only reported
//
// Prints PASS/FAIL lines; exits non-zero on any failure.
//
// When you replace the `notes` example, replace the "notes" section below with the same kinds of
// checks for your collections (owner-only list/view, spoofed owner rejected, other user blind,
// realtime only delivers own records) and update EXPECTED_COLLECTIONS.

import { readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const EXPECTED_COLLECTIONS = ["notes"]

const BASE = (process.env.PB_URL || "http://127.0.0.1:8090").replace(/\/+$/, "")
const run = Math.random().toString(36).slice(2, 8)
const NO_HOOKS = process.env.NO_HOOKS === "1"
const SHARED_PB = process.env.SHARED_PB === "1"

let failures = 0
let passes = 0
const pass = (name) => { passes++; console.log(`PASS ${name}`) }
const fail = (name, detail) => { failures++; console.log(`FAIL ${name}${detail ? ` — ${detail}` : ""}`) }
const check = (name, ok, detail) => (ok ? pass(name) : fail(name, detail))
const sleep = (ms) => new Promise((r) => setTimeout(r, ms))

async function api(method, path, { token, body } = {}) {
  const headers = { "Content-Type": "application/json" }
  if (token) headers.Authorization = token
  const res = await fetch(BASE + path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) })
  const text = await res.text()
  let json = null
  try { json = text ? JSON.parse(text) : null } catch { json = { raw: text } }
  return { status: res.status, json }
}

async function login(collection, email, password) {
  const r = await api("POST", `/api/collections/${collection}/auth-with-password`, { body: { identity: email, password } })
  if (r.status !== 200) throw new Error(`login ${collection} ${email}: HTTP ${r.status}`)
  return { token: r.json.token, id: r.json.record.id, email }
}

// Minimal PocketBase realtime (SSE) client.
async function realtime(token, topics) {
  const controller = new AbortController()
  const res = await fetch(BASE + "/api/realtime", { headers: { Accept: "text/event-stream" }, signal: controller.signal })
  if (!res.ok) throw new Error(`realtime connect HTTP ${res.status}`)
  const events = []
  const waiters = []
  let resolveConnect
  const connected = new Promise((r) => { resolveConnect = r })
  const decoder = new TextDecoder()
  let buffer = ""
  ;(async () => {
    try {
      for await (const chunk of res.body) {
        buffer += decoder.decode(chunk, { stream: true })
        let idx
        while ((idx = buffer.indexOf("\n\n")) >= 0) {
          const raw = buffer.slice(0, idx)
          buffer = buffer.slice(idx + 2)
          let event = "message"
          let data = ""
          for (const line of raw.split("\n")) {
            if (line.startsWith("event:")) event = line.slice(6).trim()
            else if (line.startsWith("data:")) data += line.slice(5).trim()
          }
          let parsed = null
          try { parsed = JSON.parse(data) } catch { parsed = data }
          if (event === "PB_CONNECT") resolveConnect(parsed.clientId)
          else {
            events.push({ event, data: parsed })
            for (const w of [...waiters]) w()
          }
        }
      }
    } catch { /* aborted */ }
  })()
  const clientId = await Promise.race([connected, sleep(5000).then(() => { throw new Error("no PB_CONNECT") })])
  const sub = await fetch(BASE + "/api/realtime", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: token },
    body: JSON.stringify({ clientId, subscriptions: topics }),
  })
  if (sub.status !== 204) throw new Error(`realtime subscribe HTTP ${sub.status}`)
  return {
    events,
    async waitFor(pred, ms = 5000) {
      const deadline = Date.now() + ms
      for (;;) {
        const hit = events.find(pred)
        if (hit) return hit
        const left = deadline - Date.now()
        if (left <= 0) return null
        await new Promise((r) => { waiters.push(r); setTimeout(r, left) })
        waiters.length = 0
      }
    },
    close() { controller.abort() },
  }
}

// collections.json (for "Import collections" on an existing PocketBase) must match what the
// migrations produced on this server: fields, types, options, rules, indexes, ids.
async function collectionsJsonCheck(token) {
  const file = join(dirname(fileURLToPath(import.meta.url)), "..", "pocketbase", "collections.json")
  const wanted = JSON.parse(readFileSync(file, "utf8"))
  const canon = (v) => Array.isArray(v) ? v.map(canon)
    : v && typeof v === "object" ? Object.fromEntries(Object.keys(v).sort().filter((k) => k !== "created" && k !== "updated").map((k) => [k, canon(v[k])]))
    : v
  const diffs = []
  for (const c of wanted) {
    const r = await api("GET", `/api/collections/${c.name}`, { token })
    if (r.status !== 200) { diffs.push(`${c.name}: HTTP ${r.status}`); continue }
    for (const key of new Set([...Object.keys(c), ...Object.keys(r.json)])) {
      if (key === "created" || key === "updated") continue
      if (JSON.stringify(canon(c[key])) !== JSON.stringify(canon(r.json[key]))) diffs.push(`${c.name}.${key}`)
    }
  }
  // Every migrated collection must be in the file too (users stays out: an existing server has its own).
  const all = await api("GET", "/api/collections?perPage=500", { token })
  const migrated = (all.json?.items || []).filter((c) => !c.system && c.name !== "users").map((c) => c.name).sort()
  const names = wanted.map((c) => c.name).sort()
  const missing = [...EXPECTED_COLLECTIONS].filter((n) => !names.includes(n))
  check("collections.json matches the migrated schema",
    diffs.length === 0 && names.join(",") === migrated.join(",") && missing.length === 0,
    (diffs.join(", ") || `file: ${names.join(",")} / migrated: ${migrated.join(",")}` + (missing.length ? ` / tests need: ${missing.join(",")}` : "")) +
    " (run scripts/export-collections.sh)")
}

async function main() {
  console.log(`.... e2e against ${BASE}${NO_HOOKS ? " (hooks disabled)" : ""}${SHARED_PB ? " (imported schema)" : ""}`)
  const health = await api("GET", "/api/health")
  check("server healthy", health.status === 200, `HTTP ${health.status}`)

  const { PB_ADMIN_EMAIL, PB_ADMIN_PASSWORD, PB_APP_EMAIL, PB_APP_PASSWORD } = process.env
  if (!PB_ADMIN_EMAIL || !PB_ADMIN_PASSWORD) throw new Error("set PB_ADMIN_EMAIL and PB_ADMIN_PASSWORD")
  const admin = await login("_superusers", PB_ADMIN_EMAIL, PB_ADMIN_PASSWORD)
  pass("superuser login")
  await collectionsJsonCheck(admin.token)

  // --- users ---------------------------------------------------------------------------
  const signup = await api("POST", "/api/collections/users/records", {
    body: { email: `signup-${run}@example.invalid`, password: "signup-password-1", passwordConfirm: "signup-password-1" },
  })
  if (SHARED_PB) {
    console.log(`INFO users self-registration is ${signup.status >= 400 ? "off" : "on"} (the existing server's own policy)`)
    if (signup.status === 200) await api("DELETE", `/api/collections/users/records/${signup.json.id}`, { token: admin.token })
  } else {
    check("public self-registration is off", signup.status >= 400, `HTTP ${signup.status}`)
  }

  async function makeUser(tag) {
    const email = `${tag}-${run}@example.invalid`
    const password = `pw-${tag}-${run}-0123456789`
    const r = await api("POST", "/api/collections/users/records", {
      token: admin.token, body: { email, password, passwordConfirm: password, verified: true },
    })
    if (r.status !== 200) throw new Error(`create user ${tag}: HTTP ${r.status} ${JSON.stringify(r.json)}`)
    return login("users", email, password)
  }

  let A
  if (PB_APP_EMAIL && PB_APP_PASSWORD) {
    A = await login("users", PB_APP_EMAIL, PB_APP_PASSWORD)
    pass("provisioned app login works")
  } else {
    A = await makeUser("usera")
  }
  const B = await makeUser("userb")
  pass("user logins (A and B)")

  // --- notes (the example collection) ---------------------------------------------------
  const aRT = await realtime(A.token, ["notes"])
  const bRT = await realtime(B.token, ["notes"])
  pass("realtime connected and subscribed (A, B)")

  const create = (user, body) => api("POST", "/api/collections/notes/records", { token: user.token, body })
  const n1 = await create(A, { owner: A.id, title: `a1-${run}`, body: "first" })
  const n2 = await create(A, { owner: A.id, title: `a2-${run}`, done: true })
  const nb = await create(B, { owner: B.id, title: `b1-${run}` })
  check("A creates 2 notes, B creates 1", n1.status === 200 && n2.status === 200 && nb.status === 200,
    `${n1.status}/${n2.status}/${nb.status} ${JSON.stringify(n1.json)}`)
  check("created note has the expected fields", n1.json?.owner === A.id && n1.json?.title === `a1-${run}` && n1.json?.done === false
    && n2.json?.done === true && typeof n1.json?.created === "string")

  const noOwner = await create(A, { title: `noowner-${run}` })
  check("create without owner rejected", noOwner.status === 400, `HTTP ${noOwner.status}`)
  const spoof = await create(A, { owner: B.id, title: `spoof-${run}` })
  check("create with spoofed owner rejected", spoof.status === 400 || spoof.status === 403, `HTTP ${spoof.status}`)
  const noTitle = await create(A, { owner: A.id, body: "x" })
  check("create without required title rejected", noTitle.status === 400, `HTTP ${noTitle.status}`)
  const guestCreate = await api("POST", "/api/collections/notes/records", { body: { owner: A.id, title: `guest-${run}` } })
  check("guest cannot create", guestCreate.status >= 400, `HTTP ${guestCreate.status}`)

  const aList = await api("GET", "/api/collections/notes/records?perPage=200&sort=created", { token: A.token })
  const aTitles = (aList.json?.items || []).map((n) => n.title)
  check("A lists only its own notes", aTitles.includes(`a1-${run}`) && aTitles.includes(`a2-${run}`)
    && !aTitles.includes(`b1-${run}`) && (aList.json?.items || []).every((n) => n.owner === A.id), JSON.stringify(aTitles))
  const spoofStored = aTitles.concat((await api("GET", "/api/collections/notes/records?perPage=200", { token: B.token })).json?.items?.map((n) => n.title) || [])
    .some((t) => t === `spoof-${run}` || t === `noowner-${run}`)
  check("rejected notes were not stored", !spoofStored)
  const bList = await api("GET", "/api/collections/notes/records?perPage=200", { token: B.token })
  const bTitles = (bList.json?.items || []).map((n) => n.title)
  check("B lists only its own notes", bTitles.includes(`b1-${run}`) && !bTitles.includes(`a1-${run}`), JSON.stringify(bTitles))
  // scoped to this run: the app login may also own starter notes from pocketbase/seed
  const filtered = await api("GET", `/api/collections/notes/records?filter=${encodeURIComponent(`done=true && title~"-${run}"`)}`, { token: A.token })
  check("A filters its notes (done=true)", (filtered.json?.items || []).map((n) => n.title).join() === `a2-${run}`)

  const bView = await api("GET", `/api/collections/notes/records/${n1.json.id}`, { token: B.token })
  check("B cannot view A's note", bView.status === 404, `HTTP ${bView.status}`)
  const bPatch = await api("PATCH", `/api/collections/notes/records/${n1.json.id}`, { token: B.token, body: { title: "hacked" } })
  check("B cannot update A's note", bPatch.status === 404, `HTTP ${bPatch.status}`)
  const bDel = await api("DELETE", `/api/collections/notes/records/${n1.json.id}`, { token: B.token })
  check("B cannot delete A's note", bDel.status === 404, `HTTP ${bDel.status}`)
  const guestList = await api("GET", "/api/collections/notes/records")
  check("guest sees no notes", guestList.status === 200 && guestList.json.items.length === 0, `HTTP ${guestList.status}`)
  const guestView = await api("GET", `/api/collections/notes/records/${n1.json.id}`)
  check("guest cannot view a note", guestView.status === 404, `HTTP ${guestView.status}`)

  const handOver = await api("PATCH", `/api/collections/notes/records/${n1.json.id}`, { token: A.token, body: { owner: B.id } })
  check("A cannot hand its note to another owner", handOver.status >= 400, `HTTP ${handOver.status}`)
  const edit = await api("PATCH", `/api/collections/notes/records/${n1.json.id}`, { token: A.token, body: { done: true, title: `a1-${run}-edited` } })
  check("A updates its own note", edit.status === 200 && edit.json.done === true && edit.json.owner === A.id, `HTTP ${edit.status}`)
  const sameOwner = await api("PATCH", `/api/collections/notes/records/${n1.json.id}`, { token: A.token, body: { owner: A.id, body: "x" } })
  check("A may resend its own owner on update", sameOwner.status === 200, `HTTP ${sameOwner.status}`)

  // Realtime: each user receives its own creates and nothing of the other's.
  const aGot = await aRT.waitFor((e) => e.event === "notes" && e.data?.action === "create" && e.data?.record?.id === n1.json.id)
  check("A receives its own create via realtime SSE", !!aGot && aGot.data.record.title === `a1-${run}`)
  const bGot = await bRT.waitFor((e) => e.event === "notes" && e.data?.action === "create" && e.data?.record?.id === nb.json.id)
  check("B receives its own create via realtime SSE", !!bGot)
  await sleep(300)
  const aIds = new Set([n1.json.id, n2.json.id])
  const leakedToB = bRT.events.filter((e) => e.event === "notes" && aIds.has(e.data?.record?.id))
  const leakedToA = aRT.events.filter((e) => e.event === "notes" && e.data?.record?.id === nb.json.id)
  check("realtime never delivers another user's notes", leakedToB.length === 0 && leakedToA.length === 0,
    `${leakedToB.length} to B, ${leakedToA.length} to A`)
  aRT.close(); bRT.close()

  const del = await api("DELETE", `/api/collections/notes/records/${n2.json.id}`, { token: A.token })
  check("A deletes its own note", del.status === 204, `HTTP ${del.status}`)

  // --- cleanup (deleting a user cascades to its notes) -----------------------------------
  await api("DELETE", `/api/collections/users/records/${B.id}`, { token: admin.token })
  if (PB_APP_EMAIL && PB_APP_PASSWORD) {
    await api("DELETE", `/api/collections/notes/records/${n1.json.id}`, { token: A.token })
  } else {
    await api("DELETE", `/api/collections/users/records/${A.id}`, { token: admin.token })
  }
  const gone = await api("GET", `/api/collections/notes/records/${nb.json.id}`, { token: admin.token })
  check("deleting a user cascades to its notes", gone.status === 404, `HTTP ${gone.status}`)
}

main()
  .catch((e) => { fail("unexpected error", e.message) })
  .finally(() => {
    console.log(failures === 0 ? `ALL PASS (${passes} checks)` : `${failures} FAILED, ${passes} passed`)
    process.exit(failures === 0 ? 0 : 1)
  })
