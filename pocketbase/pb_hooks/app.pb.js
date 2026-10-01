/// <reference path="../pb_data/types.d.ts" />
// Server-side hooks (PocketBase JS VM).
//
// Hooks are OPTIONAL for access control: every rule in pb_migrations/ is self-sufficient, so the
// schema stays safe when this directory is not loaded (an existing PocketBase that imported
// collections.json, or `--hooksDir` pointing elsewhere). Use hooks for behaviour, not security.
//
// Note: every handler runs in its own isolated runtime, so everything it needs must live inside
// the handler (no shared top-level variables or helpers).

// Console command used by scripts/provision.sh (and the container on first start) to create
// the app login without going through the HTTP API:
//   pocketbase app-user <email> <password> --dir ... --migrationsDir ... --hooksDir ...
// Creates the `users` record if missing, otherwise sets its password. Idempotent.
$app.rootCmd.addCommand(new Command({
  use: "app-user <email> <password>",
  short: "Create or update an app login (a verified users record)",
  run: (cmd, args) => {
    if (!args || args.length !== 2) {
      throw new Error("usage: app-user <email> <password>")
    }
    const email = args[0]
    const password = args[1]
    let record
    let created = false
    try {
      record = $app.findAuthRecordByEmail("users", email)
    } catch (_) {
      record = new Record($app.findCollectionByNameOrId("users"))
      record.setEmail(email)
      created = true
    }
    record.setPassword(password)
    record.setVerified(true)
    $app.save(record)
    console.log((created ? "Created" : "Updated") + " app user " + email)
  },
}))

// Home Assistant auto-login for the sidebar panel (see lib/halogin.js). Off unless HA_AUTO_LOGIN=true.
routerAdd("GET", "/api/app/ha-login", (e) => require(`${__hooks}/lib/halogin.js`).haLogin(e))

// Example hook (disabled): trim note titles before they are saved. Uncomment to try it; the
// e2e tests do not depend on it.
//
// onRecordCreateRequest((e) => {
//   e.record.set("title", e.record.getString("title").trim())
//   e.next()
// }, "notes")
