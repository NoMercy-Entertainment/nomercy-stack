#!/usr/bin/env python3
"""The web scan jails ban scanners, never a normal visitor (stack#4).

Expands the real filter files the way fail2ban does (%(name)s and <HOST>), runs
them on proxy access-log lines in the main_timed format (proxy/nginx.conf), and
checks that the jails end a ban. Exit 1 lists every failure.
"""
import configparser
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / "fail2ban/config/fail2ban"
JAILS = ["nginx-wp-scan", "nginx-aggressive-scan", "nginx-vuln-scan"]
# fail2ban's <HOST> for an address; enough to prove which field it binds to.
HOST = r"(?P<host>(?:\d{1,3}\.){3}\d{1,3}|[0-9a-fA-F:]+:[0-9a-fA-F:]+)"
VISITOR = "198.51.100.7"
EDGE = "203.0.113.9"


def line(request, status="404", referer="-", agent="Mozilla/5.0"):
    return (f'[12/Nov/2026:02:00:00 +0100] "{request}" {status} 153 "{referer}" '
            f'"{agent}" {VISITOR} {EDGE} 0.010 0.010 . -')


def read(path):
    parser = configparser.RawConfigParser(strict=False)
    parser.optionxform = str
    for name in (path.with_suffix(".conf"), path.with_suffix(".local")):
        if name.exists():
            parser.read(name, encoding="utf-8")
    return parser


def regexes(jail):
    d = dict(read(ROOT / "filter.d" / jail).items("Definition"))
    out = []
    for raw in d["failregex"].strip().splitlines():
        rx = raw.strip()
        for _ in range(5):
            rx = re.sub(r"%\((\w+)\)s", lambda m: d[m.group(1)], rx)
        out.append(re.compile(rx.replace("<HOST>", HOST)))
    return out


def banned(jail, text):
    for rx in regexes(jail):
        m = rx.search(text)
        if m:
            return m.group("host")
    return None


# Lines a real visitor sends. None of them may ban.
VISITORS = [
    line("GET /api/v1/music/nowplaying HTTP/1.1"),
    line("GET /newpage HTTP/1.1", referer="https://nomercy.tv/newpage"),
    line("GET /app/settings HTTP/2.0"),
    line("GET /search?q=wordpress HTTP/2.0"),
    line("GET /search?q=.env HTTP/2.0"),
    line("GET /admin/users/0000 HTTP/2.0"),
    line("GET /api/v1/admin/servers HTTP/2.0"),
    line("GET /blog/2026-roundup HTTP/2.0"),
    line("GET /docs/contributing-to-github HTTP/2.0"),
    line("GET /nowplaying HTTP/2.0", agent="NoMercy wp-app/1.0"),
]
# Probes a scanner sends: each must ban the visitor address, not the edge one.
PROBES = {
    "nginx-wp-scan": [line("GET /wp-login.php HTTP/1.1"), line("GET /.env HTTP/1.1", status="403"),
                      line("POST /xmlrpc.php HTTP/1.1", status="405"), line("GET /.git/config HTTP/1.1")],
    "nginx-aggressive-scan": [line("GET /backup HTTP/1.1"), line("GET /site.zip HTTP/1.1"),
                              line("GET /old/index.php HTTP/1.1"), line("GET /phpmyadmin/ HTTP/1.1")],
    "nginx-vuln-scan": [line("GET /.env HTTP/1.1"), line("GET /.aws/credentials HTTP/1.1"),
                        line("GET /cgi-bin/alfacgiapi/perl.alfa HTTP/1.1")],
}

failures = []
for jail in JAILS:
    for text in VISITORS:
        if banned(jail, text):
            failures.append(f"{jail} bans a visitor: {text}")
    for text in PROBES[jail]:
        host = banned(jail, text)
        if host != VISITOR:
            failures.append(f"{jail} misses a probe (got {host}): {text}")
    for name in sorted((ROOT / "jail.d").glob(jail + ".*")):
        # No inline comment stripping: fail2ban keeps "604800   # note" as the value,
        # finds it is not a number and silently falls back to its default.
        parser = configparser.RawConfigParser(strict=False)
        parser.read(name, encoding="utf-8")
        for key in ("bantime", "maxretry", "findtime"):
            value = parser.get(jail, key, fallback=None)
            if value is not None and not re.fullmatch(r"-?\d+", value.strip()):
                failures.append(f"{name.name}: {key} = {value.strip()!r} is not a plain number")
        bantime = parser.get(jail, "bantime", fallback=None)
        if bantime is not None and bantime.strip().startswith("-"):
            failures.append(f"{name.name}: bantime {bantime.strip()} bans for ever")

# Every jail file: number settings must be plain numbers (an inline comment makes
# fail2ban fall back to its default without an error).
for name in sorted((ROOT / "jail.d").glob("*")):
    parser = configparser.RawConfigParser(strict=False)
    parser.read(name, encoding="utf-8")
    for section in parser.sections():
        for key in ("bantime", "maxretry", "findtime"):
            value = parser.get(section, key, fallback=None)
            if value is not None and "%" not in value and not re.fullmatch(r"-?\d+[smhdw]?", value.strip()):
                failures.append(f"{name.name} [{section}]: {key} = {value.strip()!r} is not a plain number")

# No action a jail uses may put a secret on a command line: a process list in
# the container shows it (a Cloudflare token leaked that way, 2026-11-12).
SECRET = re.compile(r"<\w*(?:token|apikey|api_key|secret|password)\w*>", re.I)
used = set()
for name in (ROOT / "jail.d").glob("*"):
    for m in re.finditer(r"^\s*(?:action\s*=)?\s*([\w-]+)\[", name.read_text(encoding="utf-8"), re.M):
        used.add(m.group(1))
for action in sorted(used):
    for path in (ROOT / "action.d" / f"{action}.conf", ROOT / "action.d" / f"{action}.local"):
        if not path.exists():
            continue
        for n, text in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if not text.lstrip().startswith("#") and SECRET.search(text):
                failures.append(f"{path.name}:{n} puts a secret on a command line: {SECRET.search(text).group(0)}")

for f in failures:
    print("FAIL", f)
print(f"{len(failures)} failure(s) over {len(JAILS)} jails, {len(VISITORS)} visitor lines, "
      f"{sum(len(v) for v in PROBES.values())} probes")
sys.exit(1 if failures else 0)
