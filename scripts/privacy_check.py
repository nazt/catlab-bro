#!/usr/bin/env python3
"""Scan every file Git would commit for things a public repo must not contain.

Checks tracked + untracked-but-not-ignored files: workstation paths, private network addresses,
credentials in URLs, private keys, access tokens, PocketBase credential files and symlinks.
Run before every commit; CI runs it on every push. Exit status 1 on any finding.
"""
import argparse
import pathlib
import re
import subprocess
import sys

parser = argparse.ArgumentParser()
parser.add_argument("--deny-term", action="append", default=[],
                    help="extra text that must not appear (e.g. an internal host name)")
args = parser.parse_args()

root = pathlib.Path(__file__).resolve().parent.parent
names = subprocess.check_output(
    ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"], cwd=root
).decode().split("\0")

rules = {
    "absolute workstation path": r"/(?:Users|opt/Code|home)/[A-Za-z0-9._-]+/",
    "private network address": r"\b(?:192\.168\.\d+\.\d+|10\.\d+\.\d+\.\d+|172\.(?:1[6-9]|2\d|3[01])\.\d+\.\d+"
                               r"|100\.(?:6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.\d+\.\d+)\b",
    "credential-bearing URL": r"\b(?:https?|rtsp|mqtts?|wss?)://[^\s/\"'@]+:[^\s/@\"']+@",
    "private key material": r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----",
    "literal access token": r"\b(?:ghp_|github_pat_|gho_|sk-proj-|sk-ant-|xox[bp]-)[A-Za-z0-9_\-]{16,}",
    "generated PocketBase password": r"\b(?:admin|app)_password=[A-Za-z0-9]{16,}",
}
blocked_names = ("initial-credentials.txt", ".provision-state", "data.db", "auxiliary.db")

failures = []
count = 0
for name in sorted(set(names) - {""}):
    path = root / name
    if path.is_symlink():
        failures.append(f"{name}: symbolic link (not portable; copy the file instead)")
        continue
    if not path.is_file():
        continue
    count += 1
    if path.name in blocked_names or name.startswith("pb_data/") or path.name == ".env":
        failures.append(f"{name}: PocketBase data or local settings must never be committed")
        continue
    if name == "scripts/privacy_check.py":   # holds the patterns themselves
        continue
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    # Home Assistant's fixed Supervisor network (the same on every install), not a private host.
    text = re.sub(r"\b172\.30\.32\.[12]\b", "<ha-supervisor>", text)
    for label, pattern in rules.items():
        if re.search(pattern, text):
            failures.append(f"{name}: {label}")
    for term in args.deny_term:
        if term.lower() in text.lower():
            failures.append(f"{name}: forbidden term")

if failures:
    print("Privacy check FAILED:")
    for f in failures:
        print("  " + f)
    sys.exit(1)
print(f"Privacy check passed: {count} candidate files; no workstation paths, private addresses, "
      "credentials or PocketBase data.")
