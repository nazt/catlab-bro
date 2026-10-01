// Drop-in migrations for the panel: which files in the drop-in folder are not applied yet, and a
// restart (PocketBase applies pending migrations when it starts). Superusers only.
//
//   EXTRA_DIR         the drop-in folder (/config in the add-on = /addon_configs/<slug>/ on the host)
//   SUPERVISOR_TOKEN  set by Home Assistant (hassio_api): lets the add-on restart itself

/** Names of migration files PocketBase has applied. */
function applied(app) {
  const rows = arrayOf(new DynamicModel({ file: "" }))
  app.db().newQuery("SELECT file FROM _migrations").all(rows)
  return rows.map((r) => r.file)
}

/** GET /api/app/migrations -> {dir, files: [{name, applied}], pending} */
function status(e) {
  const dir = ($os.getenv("EXTRA_DIR") || "").trim()
  if (!dir) return e.json(200, { dir: "", files: [], pending: 0, note: "no drop-in folder configured" })
  const done = applied(e.app)
  let names = []
  try {
    names = $os.readDir(dir + "/pb_migrations").map((d) => d.name()).filter((n) => n.endsWith(".js")).sort()
  } catch (_) {}
  const files = names.map((name) => ({ name, applied: done.indexOf(name) >= 0 }))
  return e.json(200, { dir, files, pending: files.filter((f) => !f.applied).length })
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

module.exports = { applied, status, upload, restart }
