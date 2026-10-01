// The app UI: run.sh loads a release's dist.zip (ui_repo + ui_version) into <UI_DIR>/current at
// start and serves it at "/". This notices a newer release while running, tells Home Assistant
// (a persistent notification), and on a superuser's click swaps the new build in place, no
// restart. The panel can also change the source (ui_version) itself. Adapted from
// laris-co/message-relay-v3 (pb_hooks/lib/uiupdate.js).
//
//   UI_DIR            where run.sh keeps the loaded build (<dir>/current); unset = not managed
//   UI_REPO           owner/repo whose GitHub releases carry dist.zip
//   UI_CHANNEL        ui_version: "latest" follows new releases; a tag or URL is pinned;
//                     "bundled" = no app UI
//   SETUP_SRC         the landing page (pb_public), copied into every build as /_setup
//   SUPERVISOR_TOKEN  inside a Home Assistant add-on: the notification (homeassistant_api) and
//                     saving a new ui_version from the panel (hassio_api, /addons/self/options)

const CHECK_EVERY_MS = 15 * 60 * 1000

/** The release tag a build carries: <meta name="ui-version" content="ui-v0.2.1">; "" if none. */
function versionOf(html) {
  const m = /<meta\s+name="ui-version"\s+content="([^"]*)"/i.exec(String(html || ""))
  return m && m[1] !== "%UI_VERSION%" ? m[1] : ""
}

/** A tag safe in a URL and a shell line: ui-v1.2.3, v1.2.3, v1.2.3-rc.1. */
const validTag = (t) => /^(ui-)?v\d+\.\d+\.\d+([.-][0-9A-Za-z.-]+)?$/.test(String(t || ""))

/** What ui_version may be: latest | a release tag | an http(s) dist.zip URL | bundled. A URL may
 *  not hold a quote or a space: it ends up inside a single-quoted shell word. */
function validSource(s) {
  s = String(s || "")
  return s === "latest" || s === "bundled" || validTag(s) ||
    /^https?:\/\/[A-Za-z0-9._~:\/?#\[\]@!$&()*+,;=%-]+$/.test(s)
}

/** Is tag a newer than tag b? Numeric by part (ui-v0.10.0 > ui-v0.9.9); an unknown b counts as older. */
function isNewer(a, b) {
  if (!validTag(a)) return false
  if (!validTag(b)) return true
  const n = (t) => t.replace(/^ui-/, "").slice(1).split(/[.-]/).slice(0, 3).map(Number)
  const x = n(a), y = n(b)
  for (let i = 0; i < 3; i++) if (x[i] !== y[i]) return x[i] > y[i]
  return false
}

/** Home Assistant's Supervisor API (SUPERVISOR_URL only for tests: scripts/fake-supervisor.py). */
const supervisor = () => (($os.getenv("SUPERVISOR_URL") || "").trim() || "http://supervisor").replace(/\/+$/, "")

function env() {
  const g = (k) => ($os.getenv(k) || "").trim()
  return { dir: g("UI_DIR"), repo: g("UI_REPO"), channel: g("UI_CHANNEL") || "latest", setup: g("SETUP_SRC"), token: g("SUPERVISOR_TOKEN") }
}

/** The source in force: one saved from the panel since this start, else the one run.sh loaded. */
function channelOf(app) {
  return app.store().get("ui.channel") || env().channel
}

function installed(dir) {
  try { return versionOf(toString($os.readFile(dir + "/current/index.html"))) } catch (_) { return "" }
}

const validRepo = (r) => /^[A-Za-z0-9._-]+\/[A-Za-z0-9._-]+$/.test(String(r || ""))
const releaseZip = (repo, tag) => "https://github.com/" + repo + "/releases/download/" + tag + "/dist.zip"

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
      url: supervisor() + "/core/api/services/persistent_notification/" + service,
      method: "POST",
      headers: { authorization: "Bearer " + token, "content-type": "application/json" },
      body: JSON.stringify(body),
      timeout: 10,
    })
  } catch (err) {
    console.log("ui-update: Home Assistant notification failed: " + err)
  }
}

/** {managed, repo, channel, installed, latest, update, editable, restart}. Checks GitHub at most
 *  every 15 minutes. editable: the panel can save the source; restart: a source saved since this
 *  start takes effect at the next one. */
function status(app, force) {
  const { dir, repo, token } = env()
  const store = app.store()
  const channel = channelOf(app)
  const extra = { editable: !!token, restart: !!store.get("ui.restart") }
  if (!dir || !repo) return Object.assign({ managed: false, repo, channel, installed: "", latest: "", update: false }, extra)
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
  return Object.assign({ managed: true, repo, channel, installed: have, latest, update }, extra)
}

/** Download a dist.zip and swap it in: <dir>/new -> <dir>/current, the old one kept as <dir>/old.
 *  Throws with the shell's own words (curl's HTTP error, a zip without index.html) on failure. */
function swapIn(dir, zip, setup) {
  const script = [
    "rm -rf '" + dir + "/new' /tmp/ui-update.zip && mkdir -p '" + dir + "/new'",
    "curl -fsSL --max-time 60 -o /tmp/ui-update.zip '" + zip + "'",
    "unzip -q /tmp/ui-update.zip -d '" + dir + "/new'",
    "test -f '" + dir + "/new/index.html'",
    // now as the files' date: unzip keeps the build's, and an older date could be answered 304
    "find '" + dir + "/new' -type f -exec touch {} +",
    setup ? "rm -rf '" + dir + "/new/_setup' && cp -R '" + setup + "' '" + dir + "/new/_setup'" : "true",
    "rm -rf '" + dir + "/old' && mv '" + dir + "/current' '" + dir + "/old' && mv '" + dir + "/new' '" + dir + "/current'",
  ].join(" && ")
  const out = toString($os.cmd("sh", "-c", "(" + script + ") 2>&1 || { rm -rf '" + dir + "/new'; echo SWAP-FAILED; }").combinedOutput())
  if (out.indexOf("SWAP-FAILED") >= 0) {
    throw new Error("could not load " + zip + ": " + (out.replace("SWAP-FAILED", "").trim() || "no index.html in the zip"))
  }
}

/** Download the newest release and swap it in. */
function update(app) {
  const s = status(app, true)
  if (!s.managed) throw new Error("the UI is not managed here (no UI_DIR / UI_REPO)")
  if (!s.update) return s
  if (!validTag(s.latest)) throw new Error("bad release tag: " + s.latest)
  const { dir, repo, setup, token } = env()
  if (!validRepo(repo)) throw new Error("bad UI_REPO: " + repo)
  swapIn(dir, releaseZip(repo, s.latest), setup)
  const now = installed(dir)
  if (now !== s.latest) throw new Error("the new build says " + (now || "no version") + ", not " + s.latest)
  notify(token, "dismiss", { notification_id: "pocketbase_template_ui" })
  console.log("ui-update: " + s.installed + " -> " + now)
  return Object.assign({}, s, { installed: now, update: false })
}

/** Save an option of this add-on. Supervisor's /addons/self/options replaces them all, so the
 *  current ones go back with the one change. */
function saveOption(token, key, value) {
  const auth = { Authorization: "Bearer " + token }
  const info = $http.send({ url: supervisor() + "/addons/self/info", headers: auth, timeout: 10 })
  if (info.statusCode !== 200) throw new Error("Supervisor /addons/self/info: HTTP " + info.statusCode)
  const options = Object.assign({}, (info.json && info.json.data && info.json.data.options) || {})
  options[key] = value
  const res = $http.send({
    url: supervisor() + "/addons/self/options",
    method: "POST",
    headers: Object.assign({ "content-type": "application/json" }, auth),
    body: JSON.stringify({ options }),
    timeout: 10,
  })
  if (res.statusCode !== 200) throw new Error("Supervisor /addons/self/options: HTTP " + res.statusCode + " " + toString(res.body))
}

/** Set the app UI's source from the panel: loaded now when an app UI is already served, then
 *  saved as the add-on's ui_version (so it holds at every start). Switching to or from "bundled"
 *  changes the folder PocketBase serves, which only a restart does. */
function setSource(app, source) {
  if (!validSource(source)) throw new Error("bad source: " + source)
  const { dir, repo, setup, token, channel } = env()
  if (!token) throw new Error("not a Home Assistant add-on")
  const store = app.store()
  const live = !!dir && source !== "bundled"
  if (live) {
    let tag = "", zip = source
    if (source === "latest" || validTag(source)) {
      if (!validRepo(repo)) throw new Error("bad UI_REPO: " + repo)
      tag = source === "latest" ? latestTag(repo) : source
      if (!validTag(tag)) throw new Error("bad release tag: " + tag)
      zip = releaseZip(repo, tag)
    }
    const before = installed(dir)
    if (!tag || tag !== before) {
      swapIn(dir, zip, setup)
      const now = installed(dir)
      if (tag && now !== tag) throw new Error("the new build says " + (now || "no version") + ", not " + tag)
      console.log("ui-update: " + (before || "unknown") + " -> " + (now || zip))
    }
    if (source === "latest") { store.set("ui.latest", tag); store.set("ui.checkedAt", Date.now()) }
  }
  saveOption(token, "ui_version", source)
  store.set("ui.channel", source)
  store.set("ui.restart", !live && !(source === "bundled" && !dir && channel === "bundled"))
  console.log("ui-update: source set to " + source + " from the panel")
  return status(app, false)
}

module.exports = { versionOf, validTag, validSource, isNewer, status, update, setSource }
