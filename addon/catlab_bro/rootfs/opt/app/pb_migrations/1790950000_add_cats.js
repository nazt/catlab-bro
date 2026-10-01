/// Drop-in migration uploaded from the Catlab Bro panel: a "cats" collection, readable by any
/// signed-in user, writable by superusers only.
migrate((app) => {
  app.save(new Collection({
    type: "base",
    name: "cats",
    listRule: "@request.auth.id != ''",
    viewRule: "@request.auth.id != ''",
    fields: [
      { type: "text", name: "name", required: true },
      { type: "text", name: "breed" },
    ],
  }))
}, (app) => {
  app.delete(app.findCollectionByNameOrId("cats"))
})
