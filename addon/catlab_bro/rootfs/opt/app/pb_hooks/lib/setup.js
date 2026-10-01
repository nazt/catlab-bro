// The app's setup details for the sidebar panel: API base, app login, and a one-tap setup link
// `<scheme>://setup?u=<api base>&e=<email>&p=<password>` (shown as a QR code). Superusers only:
// the panel gets a superuser session through ha-login, nobody else sees the password.
//
//   CREDENTIALS_FILE  the provisioned credentials (/data/initial-credentials.txt)
//   PUBLIC_URL        base URL apps use (the published port, not the ingress path)
//   SETUP_SCHEME      the link's scheme (project.env SETUP_SCHEME, default the project slug)

function kv(text, key) {
  const line = text.split("\n").find((l) => l.indexOf(key + "=") === 0)
  return line ? line.slice(key.length + 1).trim() : ""
}

/** GET /api/app/setup */
function setup(e) {
  const env = (k) => ($os.getenv(k) || "").trim()
  let creds = ""
  try {
    creds = toString($os.readFile(env("CREDENTIALS_FILE")))
  } catch (_) {
    return e.json(404, { error: "no provisioned credentials file" })
  }
  const base = env("PUBLIC_URL").replace(/\/+$/, "")
  const email = kv(creds, "app_email")
  const password = kv(creds, "app_password")
  const scheme = env("SETUP_SCHEME") || "pocketbase"
  const q = (s) => encodeURIComponent(s)
  return e.json(200, {
    api: base + "/api/",
    app_email: email,
    app_password: password,
    link: scheme + "://setup?u=" + q(base) + "&e=" + q(email) + "&p=" + q(password),
    note: "the password as provisioned on first start; if it was changed later, this link is stale",
  })
}

module.exports = { kv, setup }
