// The app UI: run.sh loads a release's dist.zip (ui_repo + ui_version) into <UI_DIR>/current at
// start and serves it at "/". This notices a newer release while running, tells Home Assistant
// (a persistent notification), and on a superuser's click swaps the new build in place, no
// restart. Adapted from laris-co/message-relay-v3 (pb_hooks/lib/uiupdate.js).
//
//   UI_DIR            where run.sh keeps the loaded build (<dir>/current); unset = not managed
//   UI_REPO           owner/repo whose GitHub releases carry dist.zip
//   UI_CHANNEL        ui_version: "latest" follows new releases; a tag or URL is pinned
//   SETUP_SRC         the landing page (pb_public), copied into every build as /_setup
//   SUPERVISOR_TOKEN  inside a Home Assistant add-on (homeassistant_api): the notification

const CHECK_EVERY_MS = 15 * 60 * 1000

/** The release tag a build carries: <meta name="ui-version" content="ui-v0.2.1">; "" if none. */
function versionOf(html) {
  const m = /<meta\s+name="ui-version"\s+content="([^"]*)"/i.exec(String(html || ""))
  return m && m[1] !== "%UI_VERSION%" ? m[1] : ""
}

/** A tag safe in a URL and a shell line: ui-v1.2.3, v1.2.3, v1.2.3-rc.1. */
const validTag = (t) => /^(ui-)?v\d+\.\d+\.\d+([.-][0-9A-Za-z.-]+)?$/.test(String(t || ""))

/** Is tag a newer than tag b? Numeric by part (ui-v0.10.0 > ui-v0.9.9); an unknown b counts as older. */
function isNewer(a, b) {
  if (!validTag(a)) return false
  if (!validTag(b)) return true
  const n = (t) => t.replace(/^ui-/, "").slice(1).split(/[.-]/).slice(0, 3).map(Number)
  const x = n(a), y = n(b)
  for (let i = 0; i < 3; i++) if (x[i] !== y[i]) return x[i] > y[i]
  return false
}

function env() {
  const g = (k) => ($os.getenv(k) || "").trim()
  return { dir: g("UI_DIR"), repo: g("UI_REPO"), channel: g("UI_CHANNEL") || "latest", setup: g("SETUP_SRC"), token: g("SUPERVISOR_TOKEN") }
}

function installed(dir) {
  try { return versionOf(toString($os.readFile(dir + "/current/index.html"))) } catch (_) { return "" }
}

/** The newest release tag (unauthenticated GitHub API: 60 requests an hour; this asks 4). */
function latestTag(repo) {
  const res = $http.send({
    url: "https://api.github.com/repos/" + repo + "/releases/latest",
    headers: { accept: "application/vnd.github+json", "user-agent": "pocketbase-template" },
    timeout: 15,
  })
  if (res.statusCode !== 200) throw new Error("GitHub releases: HTTP " + res.statusCode)
  return String((res.json && res.json.tag_name) || "")
}

/** Home Assistant's notification bell, through the Supervisor's proxy to Core. */
function notify(token, service, body) {
  if (!token) return
  try {
    $http.send({
      url: "http://supervisor/core/api/services/persistent_notification/" + service,
      method: "POST",
      headers: { authorization: "Bearer " + token, "content-type": "application/json" },
      body: JSON.stringify(body),
      timeout: 10,
    })
  } catch (err) {
    console.log("ui-update: Home Assistant notification failed: " + err)
  }
}

/** {managed, repo, channel, installed, latest, update}. Checks GitHub at most every 15 minutes. */
function status(app, force) {
  const { dir, repo, channel, token } = env()
  if (!dir || !repo) return { managed: false, repo, channel: "", installed: "", latest: "", update: false }
  const store = app.store()
  const have = installed(dir)
  let latest = store.get("ui.latest") || ""
  if (channel === "latest" && (force || Date.now() - (store.get("ui.checkedAt") || 0) > CHECK_EVERY_MS)) {
    store.set("ui.checkedAt", Date.now())
    try {
      latest = latestTag(repo)
      store.set("ui.latest", latest)
    } catch (err) {
      console.log("ui-update: " + err)
    }
  }
  const update = channel === "latest" && isNewer(latest, have)
  if (update && store.get("ui.notified") !== latest) {
    store.set("ui.notified", latest)
    notify(token, "create", {
      notification_id: "pocketbase_template_ui",
      title: "A new app UI is out",
      message: "UI " + latest + " is available (running " + (have || "an older one") + "). Open the add-on's /_setup page and click Update UI: no restart needed.",
    })
    console.log("ui-update: " + latest + " is available (running " + have + ")")
  }
  return { managed: true, repo, channel, installed: have, latest, update }
}

/** Download the newest release and swap it in: <dir>/new -> <dir>/current, the old one kept as <dir>/old. */
function update(app) {
  const s = status(app, true)
  if (!s.managed) throw new Error("the UI is not managed here (no UI_DIR / UI_REPO)")
  if (!s.update) return s
  if (!validTag(s.latest)) throw new Error("bad release tag: " + s.latest)
  const { dir, repo, setup, token } = env()
  if (!/^[A-Za-z0-9._-]+\/[A-Za-z0-9._-]+$/.test(repo)) throw new Error("bad UI_REPO: " + repo)
  const zip = "https://github.com/" + repo + "/releases/download/" + s.latest + "/dist.zip"
  const script = [
    "set -e",
    "rm -rf '" + dir + "/new' /tmp/ui-update.zip && mkdir -p '" + dir + "/new'",
    "curl -fsSL --max-time 60 -o /tmp/ui-update.zip '" + zip + "'",
    "unzip -q /tmp/ui-update.zip -d '" + dir + "/new'",
    "test -f '" + dir + "/new/index.html'",
    // now as the files' date: unzip keeps the build's, and an older date could be answered 304
    "find '" + dir + "/new' -type f -exec touch {} +",
    setup ? "rm -rf '" + dir + "/new/_setup' && cp -R '" + setup + "' '" + dir + "/new/_setup'" : "true",
    "rm -rf '" + dir + "/old' && mv '" + dir + "/current' '" + dir + "/old' && mv '" + dir + "/new' '" + dir + "/current'",
  ].join(" && ")
  const out = $os.cmd("sh", "-c", script).combinedOutput()
  const now = installed(dir)
  if (now !== s.latest) throw new Error("update did not take: " + toString(out))
  notify(token, "dismiss", { notification_id: "pocketbase_template_ui" })
  console.log("ui-update: " + s.installed + " -> " + now)
  return Object.assign({}, s, { installed: now, update: false })
}

module.exports = { versionOf, validTag, isNewer, status, update }
