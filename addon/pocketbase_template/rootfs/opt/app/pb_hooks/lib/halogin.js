// Home Assistant auto-login: someone already signed in to Home Assistant who opens this add-on's
// sidebar panel is signed in to the PocketBase dashboard as the admin, with no second password.
//
// Trust comes from the CONNECTION, not the headers: Supervisor's ingress proxy connects from
// 172.30.32.2 and adds X-Ingress-Path + X-Remote-User-Id. The add-on also publishes its port, so
// anyone who reaches that port could send those headers: they are believed only when the TCP
// peer itself is the ingress proxy.
//
//   HA_AUTO_LOGIN     "true" to enable (add-on option auto_login; off outside Home Assistant)
//   HA_INGRESS_PEER   the ingress proxy address (default 172.30.32.2; tests use 127.0.0.1)
//   HA_USER_IDS       comma-separated HA user ids allowed; empty = any user ingress lets in
//   ADMIN_EMAIL       the superuser to sign in as (set by run.sh)

/** "1.2.3.4:5678" / "[::1]:5678" -> the host part. */
function peerHost(remoteAddr) {
  const s = String(remoteAddr || "")
  if (s.charAt(0) === "[") return s.slice(1, s.indexOf("]"))
  const i = s.lastIndexOf(":")
  return i > 0 && s.indexOf(":") === i ? s.slice(0, i) : s
}

/** Pure decision -> {ok: true} | {status, error}. */
function decide({ enabled, peer, trustedPeer, userId, ingressPath, allowlist }) {
  if (!enabled) return { status: 404, error: "auto-login is off" }
  if (!peer || peer !== trustedPeer) return { status: 403, error: "not via Home Assistant ingress" }
  if (!userId || !ingressPath) return { status: 403, error: "no Home Assistant identity" }
  if (allowlist.length && allowlist.indexOf(userId) < 0) return { status: 403, error: "Home Assistant user not allowed" }
  return { ok: true }
}

/** GET /api/app/ha-login */
function haLogin(e) {
  const env = (k) => ($os.getenv(k) || "").trim()
  const d = decide({
    enabled: env("HA_AUTO_LOGIN").toLowerCase() === "true",
    peer: peerHost(e.request.remoteAddr),
    trustedPeer: env("HA_INGRESS_PEER") || "172.30.32.2",
    userId: (e.request.header.get("X-Remote-User-Id") || "").trim(),
    ingressPath: (e.request.header.get("X-Ingress-Path") || "").trim(),
    allowlist: env("HA_USER_IDS").split(",").map((x) => x.trim()).filter(Boolean),
  })
  if (!d.ok) return e.json(d.status, { error: d.error })
  let admin
  try {
    admin = e.app.findAuthRecordByEmail("_superusers", env("ADMIN_EMAIL"))
  } catch (_) {
    return e.json(503, { error: "the admin login is not provisioned" })
  }
  const who = e.request.header.get("X-Remote-User-Name") || e.request.header.get("X-Remote-User-Id")
  console.log("ha-login: Home Assistant user " + who + " signed in as " + admin.email() + " via ingress")
  return $apis.recordAuthResponse(e, admin, "ha-ingress")
}

module.exports = { peerHost, decide, haLogin }
