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

// Console command used by scripts/provision.sh on the first start: load starter records from
// <dir>/<collection>.json (an array of field objects). The value "@app" in any field is replaced
// by the app login's record id (e.g. "owner": "@app"). Run once; provision.sh keeps a marker.
//   pocketbase app-seed <app-email> <dir> --dir ... --migrationsDir ... --hooksDir ...
$app.rootCmd.addCommand(new Command({
  use: "app-seed <app-email> <dir>",
  short: "Load starter records from <dir>/<collection>.json",
  run: (cmd, args) => {
    if (!args || args.length !== 2) throw new Error("usage: app-seed <app-email> <dir>")
    const appUser = $app.findAuthRecordByEmail("users", args[0])
    let total = 0
    for (const entry of $os.readDir(args[1])) {
      const file = entry.name()
      if (!file.endsWith(".json")) continue
      const collection = $app.findCollectionByNameOrId(file.slice(0, -5))
      const rows = JSON.parse(toString($os.readFile(args[1] + "/" + file)))
      for (const row of rows) {
        const record = new Record(collection)
        for (const key of Object.keys(row)) record.set(key, row[key] === "@app" ? appUser.id : row[key])
        $app.save(record)
        total++
      }
      console.log("Seeded " + rows.length + " " + collection.name)
    }
    console.log("Seeded " + total + " records")
  },
}))

// Home Assistant auto-login for the sidebar panel (see lib/halogin.js). Off unless HA_AUTO_LOGIN=true.
routerAdd("GET", "/api/app/ha-login", (e) => require(`${__hooks}/lib/halogin.js`).haLogin(e))

// The app's setup link + login for the panel (see lib/setup.js). Superusers only.
routerAdd("GET", "/api/app/setup", (e) => require(`${__hooks}/lib/setup.js`).setup(e), $apis.requireSuperuserAuth())

// Example hook (disabled): trim note titles before they are saved. Uncomment to try it; the
// e2e tests do not depend on it.
//
// onRecordCreateRequest((e) => {
//   e.record.set("title", e.record.getString("title").trim())
//   e.next()
// }, "notes")
