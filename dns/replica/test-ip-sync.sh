#!/bin/bash
# Runs ip-sync.sh once against a fake Cloudflare and a fake "what is my IP" server.
# Cases: wrong record gets fixed; equal record is left alone (no PATCH); junk address is skipped (no PATCH).
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
PORT="${FAKE_PORT:-18099}"
LOG="$(mktemp)"
trap 'kill $PID 2>/dev/null; rm -f "$LOG"' EXIT

python3 - "$PORT" "$LOG" <<'PY' &
import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer
port, log = int(sys.argv[1]), sys.argv[2]
state = {"content": "203.0.113.9", "ip": "198.51.100.7"}
class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def send(self, body, code=200):
        data = body.encode() if isinstance(body, str) else json.dumps(body).encode()
        self.send_response(code); self.send_header("Content-Length", str(len(data))); self.end_headers(); self.wfile.write(data)
    def do_GET(self):
        if self.path == "/ip": return self.send(state["ip"])
        if self.path.startswith("/set/"):
            kind, _, val = self.path[5:].partition("/")
            state[kind] = val
            return self.send("ok")
        if "/dns_records" in self.path:
            return self.send({"success": True, "result": [{"id": "rec1", "content": state["content"]}]})
        self.send("?", 404)
    def do_PATCH(self):
        n = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(n))
        state["content"] = body["content"]
        open(log, "a").write("PATCH " + body["content"] + "\n")
        self.send({"success": True, "result": {}})
HTTPServer(("127.0.0.1", port), H).serve_forever()
PY
PID=$!
sleep 1

export CF_API="http://127.0.0.1:$PORT" IP_URL="http://127.0.0.1:$PORT/ip" CF_TOKEN=t CF_ZONE_ID=z CF_RECORD_NAME=ns2.example.test ONCE=1
fail=0
check() { if [ "$2" = "$3" ]; then echo "PASS $1"; else echo "FAIL $1 (want '$3' got '$2')"; fail=1; fi; }

sh "$DIR/ip-sync.sh" >/dev/null 2>&1
check "wrong record is fixed" "$(cat "$LOG")" "PATCH 198.51.100.7"

: > "$LOG"
sh "$DIR/ip-sync.sh" >/dev/null 2>&1
check "equal record is left alone" "$(cat "$LOG")" ""

curl -s "http://127.0.0.1:$PORT/set/ip/not-an-address" >/dev/null
sh "$DIR/ip-sync.sh" >/dev/null 2>&1
check "junk address is skipped" "$(cat "$LOG")" ""

curl -s "http://127.0.0.1:$PORT/set/ip/198.51.100.99" >/dev/null
sh "$DIR/ip-sync.sh" >/dev/null 2>&1
check "new address is followed" "$(cat "$LOG")" "PATCH 198.51.100.99"

exit $fail
