#!/usr/bin/env python3
"""Fail when the Keycloak version in the realm export or the README differs from the compose image.

The recovery procedure starts the version the README names and imports the
export, so all three must say the same version as the image that runs.
"""
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent
compose = (root / 'keycloak' / 'keycloak-compose.yml').read_text(encoding='utf-8')
readme = (root / 'keycloak' / 'README.md').read_text(encoding='utf-8')
export = json.loads((root / 'keycloak' / 'realm-export.json').read_text(encoding='utf-8'))

image = re.search(r'image:\s*quay\.io/keycloak/keycloak:(\S+)', compose)
if not image:
    sys.exit('FAIL keycloak-compose.yml names no quay.io/keycloak/keycloak image')
running = image.group(1)
found = {
    'realm-export.json keycloakVersion': export.get('keycloakVersion'),
    'README Keycloak version line': (re.search(r'\*\*Keycloak version\*\*:\s*(\S+)', readme) or [None, None])[1],
    'README recovery step': (re.search(r'Start a fresh Keycloak (\S+) instance', readme) or [None, None])[1],
}
problems = [f'{where} says {value}, the image runs {running}' for where, value in found.items() if value != running]
for line in problems:
    print(f'FAIL {line}')
print(f'keycloak version: {len(problems)} problem(s)' if problems else f'keycloak version: PASS ({running} everywhere)')
sys.exit(1 if problems else 0)
