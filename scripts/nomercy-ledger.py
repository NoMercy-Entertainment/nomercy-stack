#!/usr/bin/env python3
# infra/nomercy-stack/scripts/nomercy-ledger.py
#
# Coverage ledger for the whole NoMercy stack on ONE host. It lists every
# surface the host serves (every Laravel route, Keycloak, static assets, the
# CDN, the admin panels), requests each one through this host's own nginx on
# 127.0.0.1 (so Cloudflare and DNS play no part), and writes one JSON line per
# check. Run it on the old and the new droplet, then `compare` the two ledgers.
# Built for the zero-downtime droplet migration (2026-09-25).
#
#   python3 scripts/nomercy-ledger.py run --out /root/ledger-<host> [--pass reads|writes] [--token-file F]
#   python3 scripts/nomercy-ledger.py status /root/ledger-<host>
#   python3 scripts/nomercy-ledger.py compare OLD_DIR NEW_DIR
#
# Safety:
#   --pass reads   GET/HEAD only. Safe on production.
#   --pass writes  POST/PUT/PATCH/DELETE with an empty body and no credentials.
#                  Refuses to run unless /etc/nomercy-prod-next exists AND
#                  container egress is blocked (the ledger checks both), so it
#                  can never run on production or reach the outside world.
#
# Progress: one line per check on stdout, and <out>/status.json rewritten after
# every check (total, done, counts, current, rate, eta). `status` prints it.
# Python 3.8+, standard library only (the old droplet runs 3.8).

import argparse, http.client, json, os, re, socket, ssl, subprocess, sys, time

STACK = "/opt/nomercy-stack"
APP = os.environ.get("APP_NAME", "nomercy.tv")
CLIENT_IP = os.environ.get("LEDGER_CLIENT_IP", "")   # an ADMIN_IPS entry: passes the admin allowlist
MAIN, API, AUTH, CDN = "nomercy.tv", "api.nomercy.tv", "auth.nomercy.tv", "cdn.nomercy.tv"
REALM = "NoMercyTV"


def sh(cmd, stdin=None):
    return subprocess.run(cmd, input=stdin, capture_output=True, text=True, shell=True).stdout


def website_container():
    color = open(f"{STACK}/website/.active-color").read().strip()
    return f"{APP}-website-{color}"


def mysql(sql):
    out = sh(f"docker exec -i {APP}-mysql sh -c 'mysql -uroot -p\"$MYSQL_ROOT_PASSWORD\" -N nomercy 2>/dev/null'", sql)
    return [l.split("\t") for l in out.splitlines() if l.strip()]


# One real key per route parameter, read from this host's database. The same
# rows exist on old and new (the new database is a copy), so both ledgers ask
# for the same records.
SAMPLES = {
    "case": "SELECT id FROM plugin_audit_cases ORDER BY created_at LIMIT 1",
    "listing": "SELECT id FROM plugin_listings ORDER BY created_at LIMIT 1",
    "post": "SELECT id FROM posts ORDER BY created_at LIMIT 1",
    "slug": "SELECT slug FROM posts ORDER BY created_at LIMIT 1",
    "report": "SELECT id FROM diagnostic_reports ORDER BY created_at LIMIT 1",
    "server": "SELECT id FROM servers ORDER BY created_at LIMIT 1",
    "server_user": "SELECT id FROM server_users ORDER BY created_at LIMIT 1",
    "user": "SELECT id FROM users ORDER BY created_at LIMIT 1",
    "version": "SELECT id FROM plugin_versions ORDER BY created_at LIMIT 1",
    "token": "SELECT token FROM server_invites ORDER BY created_at LIMIT 1",
    "videoId": "SELECT source_id FROM trailers ORDER BY created_at LIMIT 1",
}
LITERALS = {"lang": "en", "locale": "en", "driver": "github", "category": "marketing",
            "path": "ledger-missing.png", "role": "offline_access"}


def fill(uri, samples):
    missing = []

    def rep(m):
        name, optional = m.group(1), m.group(2) == "?"
        v = samples.get(name) or LITERALS.get(name)
        if v is None:
            if optional:
                return ""
            missing.append(name)
            return "LEDGER-UNFILLED"
        return str(v)
    path = re.sub(r"\{([^}?]+)(\??)\}", rep, uri)
    path = "/" + re.sub(r"/+", "/", path).strip("/")
    return path, missing


def inventory(pass_name):
    routes = json.loads(sh(f"docker exec {website_container()} php artisan route:list --json 2>/dev/null") or "[]")
    if not routes:
        sys.exit("no routes: is the website container running?")
    samples = {}
    for k, q in SAMPLES.items():
        rows = mysql(q + ";")
        if rows and rows[0] and rows[0][0] not in ("", "NULL"):
            samples[k] = rows[0][0]
    items = []
    for r in routes:
        methods = [m for m in r["method"].split("|") if m != "HEAD"]
        method = methods[0]
        is_read = method == "GET"
        if (pass_name == "reads") != is_read:
            continue
        host = r.get("domain") or MAIN
        path, missing = fill(r["uri"], samples)
        mw = " ".join(r.get("middleware") or [])
        needs_auth = "Authenticate" in mw or "CheckKeycloak" in mw
        base = {"kind": "route", "method": method, "host": host, "path": path, "route": r["uri"],
                "name": r.get("name"), "unfilled": missing, "needs_auth": needs_auth}
        # The route template, not the filled path: unique, and the same on every host.
        rid = f"{method} {host}/{r['uri'].lstrip('/')}"
        items.append(dict(base, id=rid, auth=False))
        if needs_auth and is_read:
            items.append(dict(base, id=f"{rid} [auth]", auth=True))
    if pass_name == "reads":
        extra = [
            (AUTH, f"/realms/{REALM}/.well-known/openid-configuration"),
            (AUTH, f"/realms/{REALM}/protocol/openid-connect/certs"),
            (AUTH, f"/realms/{REALM}/protocol/openid-connect/auth?client_id=nomercy-ui&response_type=code&scope=openid&redirect_uri=https%3A%2F%2Fapp.nomercy.tv%2F"),
            (AUTH, f"/realms/{REALM}/account"),
            (AUTH, f"/realms/{REALM}/login-actions/reset-credentials?client_id=nomercy-ui"),
            (AUTH, "/admin/master/console/"),
            (MAIN, "/build/manifest.json"), (MAIN, "/favicon.ico"), (MAIN, "/robots.txt"),
            (MAIN, "/css/inter.css"), (MAIN, "/fonts/Inter-Regular.woff2"), (MAIN, "/device.svg"),
            (CDN, "/"), ("portainer.nomercy.tv", "/api/system/status"),
            ("phpmyadmin.nomercy.tv", "/"), ("storage.nomercy.tv", "/"),
            ("ledger-unknown.example", "/"),
        ]
        for host, path in extra:
            items.append({"kind": "surface", "id": f"GET {host}{path}", "method": "GET", "host": host,
                          "path": path, "auth": False, "unfilled": [], "needs_auth": False})
    return items, samples


class LocalHTTPS(http.client.HTTPSConnection):
    """HTTPS to this host's nginx on 127.0.0.1 with the real host name in SNI."""
    def __init__(self, host, **kw):
        self._sni = host
        super().__init__("127.0.0.1", 443, context=ssl._create_unverified_context(), timeout=30, **kw)

    def connect(self):
        sock = socket.create_connection(("127.0.0.1", 443), self.timeout)
        self.sock = self._context.wrap_socket(sock, server_hostname=self._sni)


def request(item, token):
    headers = {"Host": item["host"], "User-Agent": "nomercy-ledger/1",
               "Accept": "application/json" if item["host"] == API else "text/html,application/json",
               "CF-Ray": "nomercy-ledger"}
    if CLIENT_IP:
        headers["CF-Connecting-IP"] = CLIENT_IP
    if item.get("auth") and token:
        headers["Authorization"] = f"Bearer {token}"
    body = None
    if item["method"] != "GET":
        body, headers["Content-Type"] = "{}", "application/json"
    t0 = time.time()
    try:
        c = LocalHTTPS(item["host"])
        c.request(item["method"], item["path"], body=body, headers=headers)
        r = c.getresponse()
        data = r.read()
        ctype = (r.getheader("Content-Type") or "").split(";")[0]
        keys = None
        if ctype == "application/json":
            try:
                j = json.loads(data)
                keys = sorted(j.keys()) if isinstance(j, dict) else f"list[{len(j)}]"
            except ValueError:
                keys = "invalid-json"
        loc = r.getheader("Location") or ""
        return {"status": r.status, "ctype": ctype, "bytes": len(data), "json_keys": keys,
                "location": re.sub(r"^https?://[^/]+", "", loc).split("?")[0],
                "ms": int((time.time() - t0) * 1000), "error": None}
    except Exception as e:
        return {"status": 0, "ctype": "", "bytes": 0, "json_keys": None, "location": "",
                "ms": int((time.time() - t0) * 1000), "error": f"{type(e).__name__}: {e}"[:200]}


def write_status(out, st):
    tmp = f"{out}/status.json.tmp"
    json.dump(st, open(tmp, "w"), indent=1)
    os.replace(tmp, f"{out}/status.json")


def guard_writes():
    if not os.path.exists("/etc/nomercy-prod-next"):
        sys.exit("REFUSED: --pass writes runs only on the migration target (/etc/nomercy-prod-next missing)")
    rules = sh("iptables -S DOCKER-USER")
    if "! -d 172.16.0.0/12" not in rules or "-j DROP" not in rules:
        sys.exit("REFUSED: container egress is not blocked; run with the egress kill switch on")


def cmd_run(a):
    if a.pass_name == "writes":
        guard_writes()
    os.makedirs(a.out, exist_ok=True)
    token = open(a.token_file).read().strip() if a.token_file else ""
    items, samples = inventory(a.pass_name)
    json.dump({"samples": sorted(samples), "count": len(items)}, open(f"{a.out}/inventory-{a.pass_name}.json", "w"))
    st = {"pass": a.pass_name, "host": socket.gethostname(), "total": len(items), "done": 0,
          "counts": {}, "current": None, "started": time.time(), "updated": time.time(), "state": "running"}
    ledger = open(f"{a.out}/ledger-{a.pass_name}.jsonl", "w")
    gap = 1.0 / a.rate
    for i, item in enumerate(items, 1):
        st["current"] = item["id"]
        res = request(item, token)
        rec = dict(item, **res)
        ledger.write(json.dumps(rec) + "\n")
        ledger.flush()
        bucket = "error" if res["error"] else f"{res['status'] // 100}xx"
        st["counts"][bucket] = st["counts"].get(bucket, 0) + 1
        st["done"] = i
        st["updated"] = time.time()
        rate = i / max(st["updated"] - st["started"], 0.001)
        st["eta_s"] = int((len(items) - i) / rate)
        write_status(a.out, st)
        print(f"[{i}/{len(items)}] {res['status']:3} {res['ms']:5}ms {item['id']}", flush=True)
        time.sleep(gap)
    st["state"] = "done"
    write_status(a.out, st)
    print(f"DONE {a.pass_name}: {st['total']} checks {st['counts']}", flush=True)


def cmd_status(a):
    st = json.load(open(f"{a.dir}/status.json"))
    age = int(time.time() - st["updated"])
    print(f"{st['pass']} on {st['host']}: {st['state']} {st['done']}/{st['total']} "
          f"counts={st['counts']} eta={st.get('eta_s', '?')}s last update {age}s ago | {st['current']}")
    if st["state"] == "running" and age > 60:
        print("WARNING: no progress for over 60s")


def load(d, p):
    f = f"{d}/ledger-{p}.jsonl"
    return {json.loads(l)["id"]: json.loads(l) for l in open(f)} if os.path.exists(f) else {}


def verdict(o, n):
    if n is None:
        return "MISSING-ON-NEW", "not checked on new"
    if o is None:
        return "NEW-ONLY", "not checked on old"
    if (n["error"] or n["status"] == 0) and (o["error"] or o["status"] == 0):
        if (o["error"] or "").split(":")[0] == (n["error"] or "").split(":")[0]:
            return "SAME-ERROR", n["error"]
        return "FAIL", f"old {o['error']} / new {n['error']}"
    if n["error"] or n["status"] == 0:
        return "FAIL", f"new errored: {n['error']}"
    if o["status"] != n["status"]:
        return "DIFF", f"status {o['status']} -> {n['status']}"
    if o["ctype"] != n["ctype"]:
        return "DIFF", f"type {o['ctype']} -> {n['ctype']}"
    if o["json_keys"] != n["json_keys"] and "list" not in str(o["json_keys"]):
        return "DIFF", f"json keys {o['json_keys']} -> {n['json_keys']}"
    if o["location"] != n["location"]:
        return "DIFF", f"redirect {o['location']} -> {n['location']}"
    if n["status"] >= 500:
        return "BROKEN-ON-BOTH", f"{n['status']} on old and new"
    return "MATCH", ""


def cmd_compare(a):
    old, new = load(a.old, "reads"), load(a.new, "reads")
    rows = [(k,) + verdict(old.get(k), new.get(k)) for k in sorted(set(old) | set(new))]
    counts = {}
    for _, v, _ in rows:
        counts[v] = counts.get(v, 0) + 1
    print(f"reads compared: {len(rows)}  " + "  ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    for k, v, why in rows:
        if v != "MATCH":
            print(f"  {v:15} {k}  {why}")
    writes = load(a.new, "writes")
    if writes:
        wc = {}
        for r in writes.values():
            b = "error" if r["error"] else f"{r['status'] // 100}xx"
            wc[b] = wc.get(b, 0) + 1
        print(f"writes on new only: {len(writes)}  {wc}")
        for r in writes.values():
            if r["error"] or r["status"] >= 500:
                print(f"  WRITE-5XX      {r['id']}  {r['status']} {r['error'] or ''}")
    bad = sum(counts.get(k, 0) for k in ("DIFF", "FAIL", "MISSING-ON-NEW"))
    print("RESULT:", "PASS" if bad == 0 else f"FAIL ({bad} checks)")
    sys.exit(0 if bad == 0 else 1)


def main():
    p = argparse.ArgumentParser()
    s = p.add_subparsers(dest="cmd", required=True)
    r = s.add_parser("run")
    r.add_argument("--out", required=True)
    r.add_argument("--pass", dest="pass_name", choices=["reads", "writes"], default="reads")
    r.add_argument("--token-file")
    r.add_argument("--rate", type=float, default=4.0, help="checks per second")
    st = s.add_parser("status")
    st.add_argument("dir")
    c = s.add_parser("compare")
    c.add_argument("old")
    c.add_argument("new")
    a = p.parse_args()
    {"run": cmd_run, "status": cmd_status, "compare": cmd_compare}[a.cmd](a)


if __name__ == "__main__":
    main()
