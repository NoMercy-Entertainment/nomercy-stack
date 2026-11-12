#!/usr/bin/env python3
"""No secret is ever passed on a command line (stack#8).

Every process's arguments are readable by any user on the host (`ps`, /proc/<pid>/cmdline),
and a container's processes show up in the host's process list. A secret must reach a
command through a file, stdin or an environment variable instead.

Scans every tracked shell script and compose file for a secret-named variable
(…SECRET, …PASSWORD, …TOKEN, …API_KEY) expanded inside a command argument:
  - a curl header or body:          -H "Authorization: Bearer $TOKEN", -d "x=$SECRET"
  - a password or secret option:    --password "$PW", --secret "$S", -p"$PW", -p${PW}
  - a docker env value:             docker run -e NAME="$TOKEN"
Allowed: assignments, tests, `-e NAME` without a value (docker copies it from the
environment), and `printf … > file` / `printf … | cmd` (printf is a shell builtin).
Exit 1 lists every hit as file:line.
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
NAME = r"[A-Za-z_]*(?:SECRET|PASSWORD|PASSWD|TOKEN|API_?KEY)[A-Za-z_]*"
VAR = r"\$\{?" + NAME
PATTERNS = [
    ("secret in a curl header", re.compile(r"""-H\s*["']?[^"'\n]*""" + VAR)),
    ("secret in a curl body", re.compile(r"""(?:-d|--data(?:-raw|-binary|-urlencode)?)\s+["']?[^"'@\n]*""" + VAR)),
    ("secret in a password option", re.compile(r"""(?:--password|--secret|--passwd|--token)[ =]["']?""" + VAR)),
    ("secret in a -p option", re.compile(r"""["'\s]-p["']?""" + VAR)),
    ("secret as a docker env value", re.compile(r"""-e\s+[A-Za-z_]+=["']?""" + VAR)),
]


# Planted defects: every form the check claims to catch. Each must hit, or the check is blind.
MUST_HIT = [
    'curl -H "Authorization: Bearer $TOKEN" "$URL"',
    "curl -H 'Authorization: Bearer ${CF_TOKEN}' x",
    'curl -H "X-Api-Key: ${ABUSEIPDB_API_KEY}" x',
    '  --data-urlencode "client_secret=$CLIENT_SECRET" \\',
    'curl -d "password=${ADMIN_PASSWORD}" x',
    "curl --data-raw 'token=$GH_TOKEN' x",
    'kcadm.sh config credentials --password "$KC_ADMIN_PASSWORD"',
    'tool --secret=$CLIENT_SECRET',
    'tool --token "$GITHUB_TOKEN"',
    'test: ["CMD", "mysqladmin", "ping", "-p${MYSQL_PASSWORD}"]',
    'mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "select 1"',
    'docker run -e PLANT_TOKEN="$TOKEN" alpine',
    'docker run -e TXT_UPDATER_TOKEN=${TXT_UPDATER_TOKEN} alpine',
]
# The safe forms this change uses. Each must pass, or the check blocks the fix itself.
MUST_PASS = [
    'TOKEN=$(printf \'%s\' "$CLIENT_SECRET" | curl -s --max-time 20 \\',
    '  --data-urlencode "client_secret@-" \\',
    "printf 'Authorization: Bearer %s\\n' \"$TOKEN\" > \"$AUTH_FILE\"",
    'get()  { curl -s --max-time 30 -H @"$AUTH_ARG" "$ADMIN$1"; }',
    'KC_CLI_PASSWORD="$KC_ADMIN_PASSWORD" docker exec -i -e KC_CLI_PASSWORD "$CONTAINER" \\',
    'PLANT_TOKEN="$TOKEN" docker run --rm -i -e PLANT_URL="${PLANT_URL:-}" -e PLANT_TOKEN \\',
    'test: ["CMD-SHELL", "MYSQL_PWD=\\"$$MYSQL_PASSWORD\\" mysqladmin ping -h localhost -u \\"$$MYSQL_USER\\""]',
    ': "${CLIENT_SECRET:?KEYCLOAK_ADMIN_CLIENT_SECRET missing from $ENV_FILE}"',
    '[ -n "$TOKEN" ] || exit 1',
    '      - TXT_UPDATER_TOKEN=${TXT_UPDATER_TOKEN}',
    '      KC_DB_PASSWORD: ${KEYCLOAK_DATABASE_PASSWORD}',
]


def hit(code):
    return next((why for why, rx in PATTERNS if rx.search(code)), None)


def self_test():
    bad = [f"missed planted defect: {s}" for s in MUST_HIT if not hit(s)]
    bad += [f"flagged a safe form: {s}" for s in MUST_PASS if hit(s)]
    return bad


def files():
    out = subprocess.run(["git", "-C", str(ROOT), "ls-files"], capture_output=True, text=True, check=True).stdout
    for rel in out.splitlines():
        if rel.endswith(".sh") or re.search(r"compose[^/]*\.ya?ml$", rel):
            yield rel


def main():
    broken = self_test()
    if broken:
        print("FAIL: the check itself is wrong:")
        print("\n".join(broken))
        return 1
    hits = []
    for rel in files():
        text = (ROOT / rel).read_text(encoding="utf-8", errors="replace")
        for n, raw in enumerate(text.splitlines(), 1):
            code = raw.split(" #", 1)[0] if not raw.lstrip().startswith("#") else ""
            why = hit(code)
            if why:
                hits.append(f"{rel}:{n}: {why}")
    if hits:
        print("FAIL: secrets on a command line (pass them through a file, stdin or the environment):")
        print("\n".join(hits))
        return 1
    print("PASS: no secret on a command line in any tracked shell script or compose file")
    return 0


if __name__ == "__main__":
    sys.exit(main())
