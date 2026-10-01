/// Drop-in migration uploaded from the Catlab Bro panel: a "toys" collection, readable by any
/// signed-in user, writable by superusers only.
migrate((app) => {
  app.save(new Collection({
    type: "base",
    name: "toys",
    listRule: "@request.auth.id != ''",
    viewRule: "@request.auth.id != ''",
    fields: [
      { type: "text", name: "name", required: true },
      { type: "text", name: "for_cat" },
    ],
  }))
}, (app) => {
  app.delete(app.findCollectionByNameOrId("toys"))
})
