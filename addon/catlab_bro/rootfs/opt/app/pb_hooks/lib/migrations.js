// Drop-in migrations for the panel: which files in the drop-in folder are not applied yet, and a
// restart (PocketBase applies pending migrations when it starts). Superusers only.
//
//   EXTRA_DIR         the drop-in folder (/config in the add-on = /addon_configs/<slug>/ on the host)
//   BUILTIN_MIGRATIONS the migrations shipped in the image (= pocketbase/pb_migrations in the repo)
//   REPO_URL          the repository: a drop-in not in it yet gets a "Commit to repo" link
//
// The repo is the source of truth. A drop-in is a hotfix until it is committed to
// pocketbase/pb_migrations/ with the SAME name: the next image then ships it as built-in, the
// drop-in is ignored (merge-extra.sh refuses same-name drop-ins) and PocketBase does not run it
// again (it is already in _migrations).
//   SUPERVISOR_TOKEN  set by Home Assistant (hassio_api): lets the add-on restart itself

/** Names of migration files PocketBase has applied. */
function applied(app) {
  const rows = arrayOf(new DynamicModel({ file: "" }))
  app.db().newQuery("SELECT file FROM _migrations").all(rows)
  return rows.map((r) => r.file)
}

function builtinNames() {
  const dir = ($os.getenv("BUILTIN_MIGRATIONS") || "").trim()
  try {
    return dir ? $os.readDir(dir).map((d) => d.name()) : []
  } catch (_) {
    return []
  }
}

/** GitHub's "new file" page, pre-filled: the user commits with their own login (no token here). */
function commitUrl(repo, name, content) {
  if (!repo || content.length > 6000) return ""   // long files: download and commit by hand
  return repo.replace(/\/+$/, "") + "/new/main/pocketbase/pb_migrations?filename=" +
    encodeURIComponent(name) + "&value=" + encodeURIComponent(content)
}

/** GET /api/app/migrations -> {dir, repo, files: [{name, applied, in_repo, content?, commit_url?}], pending, uncommitted} */
function status(e) {
  const dir = ($os.getenv("EXTRA_DIR") || "").trim()
  if (!dir) return e.json(200, { dir: "", files: [], pending: 0, note: "no drop-in folder configured" })
  const done = applied(e.app)
  let names = []
  try {
    names = $os.readDir(dir + "/pb_migrations").map((d) => d.name()).filter((n) => n.endsWith(".js")).sort()
  } catch (_) {}
  const builtin = builtinNames()
  const repo = ($os.getenv("REPO_URL") || "").trim()
  const files = names.map((name) => {
    const f = { name, applied: done.indexOf(name) >= 0, in_repo: builtin.indexOf(name) >= 0 }
    if (!f.in_repo) {
      f.content = toString($os.readFile(dir + "/pb_migrations/" + name))
      f.commit_url = commitUrl(repo, name, f.content)
    }
    return f
  })
  return e.json(200, {
    dir, repo, files,
    pending: files.filter((f) => !f.applied && !f.in_repo).length,
    uncommitted: files.filter((f) => !f.in_repo).length,
  })
}

/** POST /api/app/migrations {name, content}: drop a migration file into the drop-in folder. */
function upload(e) {
  const dir = ($os.getenv("EXTRA_DIR") || "").trim()
  if (!dir) return e.json(501, { error: "no drop-in folder configured" })
  const body = e.requestInfo().body || {}
  const name = String(body.name || "")
  const content = String(body.content || "")
  // <unix timestamp>_<snake_name>.js, like PocketBase's own; never a path, never a built-in name
  if (!/^\d{10}_[a-z0-9_]{1,80}\.js$/.test(name)) return e.json(400, { error: "name must look like 1790900000_add_things.js" })
  if (content.indexOf("migrate(") < 0 || content.length > 200000) return e.json(400, { error: "not a PocketBase JS migration (no migrate(...))" })
  try {
    $os.stat(dir + "/pb_migrations/" + name)
    return e.json(409, { error: name + " already exists" })
  } catch (_) {}
  $os.mkdirAll(dir + "/pb_migrations", 0o755)
  $os.writeFile(dir + "/pb_migrations/" + name, content, 0o644)
  console.log("migrations: " + name + " uploaded from the panel")
  return e.json(201, { name })
}

/** POST /api/app/restart -> 202; Home Assistant restarts the add-on, which applies pending migrations. */
function restart(e) {
  const token = ($os.getenv("SUPERVISOR_TOKEN") || "").trim()
  if (!token) return e.json(501, { error: "not running as a Home Assistant add-on: restart the container yourself" })
  const res = $http.send({
    url: "http://supervisor/addons/self/restart",
    method: "POST",
    headers: { Authorization: "Bearer " + token },
    timeout: 5,
  })
  // The restart may cut this request short; a timeout here is the expected success.
  console.log("migrations: restart requested from the panel (Supervisor HTTP " + res.statusCode + ")")
  return e.json(202, { restarting: true })
}

/** GET /api/app/info -> this build (version, commit, repo) and, under Home Assistant, whether a newer
 *  version of the add-on is out (Supervisor /addons/self/info; installing it stays a Home Assistant
 *  action: this add-on does not get the manager role it would need to update itself). */
function info(e) {
  const env = (k) => ($os.getenv(k) || "").trim()
  const out = { version: env("BUILD_VERSION") || "dev", commit: env("GIT_SHA") || "dev", repo: env("REPO_URL"), update: null }
  const token = env("SUPERVISOR_TOKEN")
  if (token) {
    try {
      const res = $http.send({ url: "http://supervisor/addons/self/info", headers: { Authorization: "Bearer " + token }, timeout: 5 })
      const d = (res.json && res.json.data) || {}
      out.update = { available: !!d.update_available, latest: d.version_latest || "", slug: d.slug || "" }
    } catch (err) {
      console.log("info: Supervisor: " + err)
    }
  }
  return e.json(200, out)
}

module.exports = { applied, builtinNames, commitUrl, status, upload, restart, info }
