#!/usr/bin/env python3
"""A stand-in for Home Assistant's Supervisor, for tests and local previews only: the endpoints
pocketbase/pb_hooks/lib/*.js call, answered the way a real Supervisor answers them. Point the
hooks at it with SUPERVISOR_URL=http://127.0.0.1:<port> and SUPERVISOR_TOKEN=<token>.

  scripts/fake-supervisor.py <port> <state-dir> [<files-dir>]

  GET  /addons/self/info       {"result":"ok","data":{slug, version, version_latest, update_available, options}}
  POST /addons/self/options    {"options":{...}} replaces the options (state-dir/options.json), as Supervisor does
  POST /addons/self/restart    counted in state-dir/restarts
  POST /core/api/services/persistent_notification/<service>   appended to state-dir/notifications.jsonl
  GET  /files/<name>           a file from <files-dir> (a dist.zip for a URL ui_version)

Every request must carry "Authorization: Bearer $SUPERVISOR_TOKEN". FAKE_VERSION / FAKE_LATEST
set the add-on's installed and newest version (equal: no update); FAKE_SLUG its slug.
"""
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

port, state = int(sys.argv[1]), sys.argv[2]
files = sys.argv[3] if len(sys.argv) > 3 else ""
token = os.environ.get("SUPERVISOR_TOKEN", "")
version = os.environ.get("FAKE_VERSION", "0.1.8")
latest = os.environ.get("FAKE_LATEST", version)
slug = os.environ.get("FAKE_SLUG", "local_pocketbase_template")
os.makedirs(state, exist_ok=True)
options_file = os.path.join(state, "options.json")
if not os.path.exists(options_file):
    with open(options_file, "w") as f:
        json.dump({"admin_email": "admin@example.invalid", "app_email": "app@example.invalid", "auto_login": True,
                   "ha_user_ids": "", "ui_repo": "", "ui_version": "latest"}, f)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        sys.stderr.write("fake-supervisor: " + (fmt % args) + "\n")

    def reply(self, code, data=None, raw=None, kind="application/json"):
        out = raw if raw is not None else json.dumps(data if data is not None else {"result": "ok", "data": {}}).encode()
        self.send_response(code)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(out)))
        self.end_headers()
        self.wfile.write(out)

    def authorized(self):
        if self.path.startswith("/files/") or self.headers.get("Authorization") == "Bearer " + token:
            return True
        self.reply(401, {"result": "error", "message": "Unauthorized"})
        return False

    def body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return json.loads(self.rfile.read(n) or b"{}")

    def do_GET(self):
        if not self.authorized():
            return
        if self.path == "/addons/self/info":
            with open(options_file) as f:
                options = json.load(f)
            return self.reply(200, {"result": "ok", "data": {
                "slug": slug, "version": version, "version_latest": latest,
                "update_available": latest != version, "options": options}})
        if self.path.startswith("/files/") and files:
            path = os.path.join(files, os.path.basename(self.path))
            if os.path.isfile(path):
                with open(path, "rb") as f:
                    return self.reply(200, raw=f.read(), kind="application/zip")
        self.reply(404, {"result": "error", "message": "not found"})

    def do_POST(self):
        if not self.authorized():
            return
        if self.path == "/addons/self/options":
            options = self.body().get("options")
            if not isinstance(options, dict) or "admin_email" not in options:
                return self.reply(400, {"result": "error", "message": "options do not match the schema"})
            with open(options_file, "w") as f:
                json.dump(options, f)
            return self.reply(200)
        if self.path == "/addons/self/restart":
            with open(os.path.join(state, "restarts"), "a") as f:
                f.write("restart\n")
            return self.reply(200)
        if self.path.startswith("/core/api/services/persistent_notification/"):
            with open(os.path.join(state, "notifications.jsonl"), "a") as f:
                f.write(json.dumps({"service": self.path.rsplit("/", 1)[1], "data": self.body()}) + "\n")
            return self.reply(200, [])
        self.reply(404, {"result": "error", "message": "not found"})


ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
