#!/usr/bin/env node
// Install or update this repository's add-on on a Home Assistant host, then START it (Home
// Assistant never starts an add-on after installing it) and wait until PocketBase answers.
// Talks to Home Assistant's websocket API (supervisor/api, what the add-on store page itself
// uses) with a long-lived access token of an admin user. Node 22+ (built-in WebSocket).
//
//   scripts/ha-deploy.mjs --ha http://homeassistant.local:8123 [--token-file F] [--repo URL]
//                         [--slug SLUG] [--port N] [--wait] [--no-start] [--logs]
//
//   --ha           Home Assistant's URL (or HA_URL)
//   --token-file   the long-lived access token (default ~/.config/ha-deploy/<host>.token, mode
//                  600; or HA_TOKEN). Create it in Home Assistant: your profile -> Security ->
//                  Long-lived access tokens. It is never printed.
//   --repo         the add-on repository (default: repository.yaml's url:)
//   --slug         the add-on slug (default: project.env ADDON_SLUG)
//   --port         publish the API on this host port (default: the add-on's own)
//   --wait         first wait until Home Assistant sees this checkout's version (config.yaml)
//                  and its prebuilt image is on GHCR: run it right after `git push`
//   --no-start     install / update only
//   --logs         print the add-on's log afterwards, passwords masked
import { createHash } from "node:crypto"
import { readFileSync, statSync, existsSync } from "node:fs"
import { homedir } from "node:os"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const root = join(dirname(fileURLToPath(import.meta.url)), "..")
const args = process.argv.slice(2)
const flag = (name) => args.includes("--" + name)
const opt = (name, fallback = "") => { const i = args.indexOf("--" + name); return i >= 0 && args[i + 1] ? args[i + 1] : fallback }
const say = (...m) => console.log("ha-deploy:", ...m)
const die = (m) => { console.error("ha-deploy: " + m); process.exit(1) }
const sleep = (ms) => new Promise((ok) => setTimeout(ok, ms))
const env = (k) => { const m = readFileSync(join(root, "project.env"), "utf8").match(new RegExp("^" + k + "=\"?([^\"\\n]*)\"?$", "m")); return m ? m[1] : "" }

const ha = (opt("ha") || process.env.HA_URL || "").replace(/\/+$/, "")
if (!/^https?:\/\/[^/]+$/.test(ha)) die("--ha http(s)://host[:port] (Home Assistant's URL) is required")
const host = new URL(ha).hostname
const repo = opt("repo") || (readFileSync(join(root, "repository.yaml"), "utf8").match(/^url:\s*(\S+)/m) || [])[1] || ""
if (!/^https:\/\/\S+$/.test(repo)) die("no repository URL: pass --repo or run scripts/ha-buttons.sh <url> once")
const slug = opt("slug") || env("ADDON_SLUG")
// Supervisor names a store add-on <first 8 hex of sha1(repository url)>_<slug>
const full = createHash("sha1").update(repo.toLowerCase()).digest("hex").slice(0, 8) + "_" + slug
const cfg = readFileSync(join(root, "addon", slug, "config.yaml"), "utf8")
const localVersion = (cfg.match(/^version:\s*"?([^"\n]+)"?/m) || [])[1] || ""
const image = (cfg.match(/^image:\s*"?([^"\n]+)"?/m) || [])[1] || ""

function token() {
  if (process.env.HA_TOKEN) return process.env.HA_TOKEN.trim()
  // ~/.config/ha-deploy/<first label of the host>.token: kvmlab1.example.ts.net -> kvmlab1.token
  const name = /^[\d.]+$/.test(host) ? host : host.split(".")[0]
  const file = opt("token-file") || join(homedir(), ".config", "ha-deploy", name + ".token")
  if (!existsSync(file)) die(`no token: create one in Home Assistant (profile -> Security -> Long-lived access tokens), then
    mkdir -p ~/.config/ha-deploy && pbpaste > ${file} && chmod 600 ${file}`)
  if (statSync(file).mode & 0o077) die(file + " is readable by others: chmod 600 " + file)
  return readFileSync(file, "utf8").trim()
}

// ---- Home Assistant websocket: auth, then supervisor/api calls -----------------------------
const ws = new WebSocket(ha.replace(/^http/, "ws") + "/api/websocket")
let nextId = 1
const waiting = new Map()
const ready = new Promise((resolve, reject) => {
  ws.onerror = () => reject(new Error("cannot reach " + ha + "/api/websocket"))
  ws.onclose = () => { for (const [, w] of waiting) w.reject(new Error("Home Assistant closed the connection")) }
  ws.onmessage = (ev) => {
    const m = JSON.parse(ev.data)
    if (m.type === "auth_required") ws.send(JSON.stringify({ type: "auth", access_token: token() }))
    else if (m.type === "auth_ok") resolve()
    else if (m.type === "auth_invalid") reject(new Error("Home Assistant refused the token (" + (m.message || "auth_invalid") + ")"))
    else if (m.type === "result" && waiting.has(m.id)) {
      const w = waiting.get(m.id); waiting.delete(m.id)
      m.success ? w.resolve(m.result) : w.reject(new Error((m.error && m.error.message) || "failed"))
    }
  }
})
function call(type, extra = {}) {
  const id = nextId++
  return new Promise((resolve, reject) => {
    waiting.set(id, { resolve, reject })
    ws.send(JSON.stringify({ id, type, ...extra }))
  })
}
const sup = (method, endpoint, data, timeout = 60) =>
  call("supervisor/api", { endpoint, method, ...(data ? { data } : {}), timeout })

// ---- the image Home Assistant will pull: is it on GHCR yet? ---------------------------------
async function imagePublished(arch, version) {
  if (!image.startsWith("ghcr.io/")) return true   // no prebuilt image: Home Assistant builds it
  const name = image.slice("ghcr.io/".length).replace("{arch}", arch)
  const t = await fetch(`https://ghcr.io/token?scope=repository:${name}:pull`).then((r) => r.json()).catch(() => ({}))
  if (!t.token) return false
  const r = await fetch(`https://ghcr.io/v2/${name}/manifests/${version}`, { method: "HEAD", headers: {
    Authorization: "Bearer " + t.token,
    Accept: "application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.v2+json,application/vnd.oci.image.manifest.v1+json" } })
  return r.ok
}

const mask = (line) => line
  .replace(/((?:password|passwd|secret|token)\s*[:=]\s*)\S+/gi, "$1•••••")
  .replace(/(login\s*:\s*\S+\s*\/\s*)\S+/gi, "$1•••••")
  .replace(/([?&]p=)[^&\s]+/g, "$1•••••")

try {
  await ready
  const info = await sup("get", "/info")
  say(`Home Assistant at ${ha} (Supervisor ${info.supervisor}, ${info.arch}); add-on ${full}`)

  const repos = await sup("get", "/store/repositories")
  if (!repos.some((r) => (r.source || "").toLowerCase() === repo.toLowerCase())) {
    say("adding the repository " + repo)
    await sup("post", "/store/repositories", { repository: repo }, 300)
  }

  if (flag("wait")) {
    say(`waiting for ${localVersion} (this checkout) in the store and its ${info.arch} image`)
    for (let i = 0; ; i++) {
      await sup("post", "/store/reload", null, 300)
      const s = await sup("get", "/store/addons/" + full).catch(() => null)
      const seen = s && s.version_latest === localVersion
      if (seen && await imagePublished(info.arch, localVersion)) break
      if (i >= 40) die(`gave up after 20 minutes: the store shows ${s ? s.version_latest : "nothing"}; is addon-image green?`)
      await sleep(30000)
    }
  } else {
    await sup("post", "/store/reload", null, 300)
  }

  const store = await sup("get", "/store/addons/" + full).catch(() => die(`${full} is not in the store: is ${repo} the right repository and ${slug} its slug?`))
  if (!store.installed) {
    say(`installing ${store.version_latest} (a prebuilt image is pulled; a build on the device takes minutes)`)
    await sup("post", `/store/addons/${full}/install`, null, 1800)
  } else if (store.update_available) {
    say(`updating ${store.version} -> ${store.version_latest}`)
    await sup("post", `/store/addons/${full}/update`, { backup: false }, 1800)
  } else {
    say(`installed ${store.version}, up to date`)
  }

  const port = opt("port")
  if (port) {
    if (!/^\d+$/.test(port)) die("--port takes a number")
    say("publishing the API on host port " + port)
    await sup("post", `/addons/${full}/options`, { network: { "8090/tcp": Number(port) } })
  }

  let a = await sup("get", `/addons/${full}/info`)
  if (!flag("no-start") && a.state !== "started") {
    say("starting (Home Assistant does not start an add-on after installing it)")
    await sup("post", `/addons/${full}/start`, null, 600)
  }
  if (!flag("no-start")) {
    for (let i = 0; i < 60 && a.state !== "started"; i++) { await sleep(2000); a = await sup("get", `/addons/${full}/info`) }
    if (a.state !== "started") die("the add-on did not start (state " + a.state + "): see its Log tab")
    const hostPort = a.network && a.network["8090/tcp"]
    if (hostPort) {
      const base = `${new URL(ha).protocol}//${host}:${hostPort}`
      let healthy = false
      for (let i = 0; i < 45 && !healthy; i++) {
        healthy = await fetch(base + "/api/health").then((r) => r.ok).catch(() => false)
        if (!healthy) await sleep(2000)
      }
      say(healthy ? `PocketBase answers at ${base}/api/` : `started, but ${base}/api/health does not answer yet (a firewall, or still migrating)`)
    }
  }

  say(`${a.name} ${a.version} is ${a.state}${a.update_available ? " (" + a.version_latest + " is out)" : ""}`)
  say(`add-on page: ${ha}/config/app/${full}/info${a.ingress ? " · the sidebar panel opens it signed in" : ""}`)

  if (flag("logs")) {
    const r = await fetch(`${ha}/api/hassio/addons/${full}/logs`, { headers: { Authorization: "Bearer " + token(), Accept: "text/plain" } })
    const text = r.ok ? await r.text() : "(no log: HTTP " + r.status + ")"
    console.log(text.trim().split("\n").slice(-40).map(mask).join("\n"))
  }
  ws.close()
} catch (err) {
  ws.close()
  die(err.message)
}
