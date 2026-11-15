#!/usr/bin/env python3
"""Check that the ledger reaches an admin panel without a client-IP header.

nginx takes the client address from CF-Connecting-IP only from Cloudflare and
the tunnel container, so a ledger that sets the header itself gets 403 on the
admin sites. The ledger must ask the panel's own container instead.
A local HTTP server plays the panel container; no Docker is needed.
"""
import http.server
import importlib.util
import os
import sys
import threading
from pathlib import Path

os.environ["LEDGER_CLIENT_IP"] = "203.0.113.7"
path = Path(__file__).resolve().parent / "nomercy-ledger.py"
spec = importlib.util.spec_from_file_location("nomercy_ledger", path)
ledger = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ledger)

seen = []


class Panel(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        seen.append(dict(self.headers.items()))
        body = b'{"Version": "0.0.0"}'
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


class Refused:
    """Stands in for nginx on 127.0.0.1:443: records the headers, serves nothing."""
    def __init__(self, host, **kw):
        pass

    def request(self, method, url, body=None, headers=None):
        seen.append(dict(headers))
        raise ConnectionRefusedError("no nginx in this test")


failures = []
server = http.server.HTTPServer(("127.0.0.1", 0), Panel)
threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    asked = []

    def address(container):
        asked.append(container)
        return "127.0.0.1"

    ledger.container_address = address
    ledger.ADMIN_UPSTREAMS = {"phpmyadmin.nomercy.tv": ("phpmyadmin", "http", server.server_port)}
    item = {"kind": "surface", "id": "GET phpmyadmin.nomercy.tv/", "method": "GET",
            "host": "phpmyadmin.nomercy.tv", "path": "/", "auth": False}
    res = ledger.request(item, "")
    if res["status"] != 200:
        failures.append("admin panel item got status %s (%s), want 200 from the panel container"
                        % (res["status"], res["error"]))
    if asked != ["nomercy.tv-phpmyadmin"]:
        failures.append("asked for container %r, want ['nomercy.tv-phpmyadmin']" % asked)

    # A public site still goes through nginx; it must not carry the header either.
    ledger.LocalHTTPS = Refused
    ledger.request({"method": "GET", "host": "nomercy.tv", "path": "/", "auth": False}, "")
    for headers in seen:
        if any(k.lower() == "cf-connecting-ip" for k in headers):
            failures.append("request to %s carried CF-Connecting-IP" % headers.get("Host"))
    if len(seen) != 2:
        failures.append("saw %d requests, want 2 (panel container, nginx)" % len(seen))
finally:
    server.shutdown()

for f in failures:
    print("FAIL " + f)
if failures:
    sys.exit(1)
print("ok   the ledger reaches an admin panel through its container and sets no client IP header")
