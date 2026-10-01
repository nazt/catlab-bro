/// <reference path="../pb_data/types.d.ts" />
// Initial schema.
//
// 1. `users`: public self-registration is switched off. Logins are created by an admin
//    (or by scripts/provision.sh through the `app-user` command in pb_hooks/app.pb.js).
// 2. `notes`: an EXAMPLE collection showing owner-only access. Replace it with your own
//    collections (see AGENTS.md, "Add a collection").
//
// The rules are self-sufficient: they enforce ownership without any pb_hooks, so the schema is
// safe on a PocketBase that runs with hooks disabled or that imported collections.json.

migrate((app) => {
  // Signed in, and the record belongs to the caller.
  const OWNER_ONLY = "@request.auth.id != '' && owner = @request.auth.id"
  // Create: the client must send `owner` and it must be the caller.
  const OWNER_CREATE = "@request.auth.id != '' && @request.body.owner = @request.auth.id"
  // Update: own record only, and `owner` can never be changed to someone else.
  const OWNER_UPDATE =
    "@request.auth.id != '' && owner = @request.auth.id && " +
    "(@request.body.owner:isset = false || @request.body.owner = @request.auth.id)"

  const users = app.findCollectionByNameOrId("users")
  users.createRule = null // superusers only
  app.save(users)

  app.save(new Collection({
    type: "base",
    name: "notes",
    listRule: OWNER_ONLY,
    viewRule: OWNER_ONLY,
    createRule: OWNER_CREATE,
    updateRule: OWNER_UPDATE,
    deleteRule: OWNER_ONLY,
    fields: [
      {
        type: "relation",
        name: "owner",
        required: true,
        collectionId: users.id,
        cascadeDelete: true,
        maxSelect: 1,
      },
      { type: "text", name: "title", required: true, max: 200 },
      { type: "text", name: "body", max: 20000 },
      { type: "bool", name: "done" },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true },
    ],
    indexes: [
      "CREATE INDEX `idx_notes_owner` ON `notes` (`owner`)",
    ],
  }))
}, (app) => {
  try {
    app.delete(app.findCollectionByNameOrId("notes"))
  } catch (_) {
    // already gone
  }
  const users = app.findCollectionByNameOrId("users")
  users.createRule = ""
  app.save(users)
})
