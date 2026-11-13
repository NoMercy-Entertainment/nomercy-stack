#!/usr/bin/env python3
"""Fail when nginx trusts a client-IP header from a wide private range, or a compose file turns seccomp off.

nginx may take the client address from CF-Connecting-IP only from Cloudflare
ranges and single tunnel addresses. A private range wider than a /32 lets any
container set the address the admin allowlists check.
"""
import ipaddress
import re
import sys
from pathlib import Path

root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent
failures = []

conf = (root / 'proxy' / 'nginx.conf').read_text(encoding='utf-8')
for m in re.finditer(r'^\s*set_real_ip_from\s+(\S+?);', conf, re.M):
    net = ipaddress.ip_network(m.group(1), strict=False)
    if net.is_private and net.num_addresses > 1:
        failures.append('proxy/nginx.conf trusts the private range %s for the client IP header' % net)

for path in sorted(root.rglob('*compose*.yml')):
    if '.git' in path.parts:
        continue
    if re.search(r'seccomp\s*[:=]\s*unconfined', path.read_text(encoding='utf-8')):
        failures.append('%s turns seccomp off' % path.relative_to(root).as_posix())

for f in failures:
    print('FAIL ' + f)
if failures:
    sys.exit(1)
print('ok   client IP trust is Cloudflare-only and no compose file turns seccomp off')
