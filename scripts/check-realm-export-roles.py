#!/usr/bin/env python3
"""Fail when keycloak/realm-export.json would bring back the retired passkey-only roles.

Two checks: the retired roles are absent, and every role an authenticator
condition names exists in the export, so no condition points at nothing.
"""
import json
import sys
from pathlib import Path

RETIRED = {'passwordless', 'disable password login'}
path = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / 'keycloak' / 'realm-export.json')
realm = json.loads(path.read_text(encoding='utf-8'))

realm_roles = {r['name'] for r in realm.get('roles', {}).get('realm', [])}
client_roles = {f'{client}.{r["name"]}' for client, roles in realm.get('roles', {}).get('client', {}).items() for r in roles}
problems = [f'retired realm role is back: {name}' for name in sorted(RETIRED & realm_roles)]
for cfg in realm.get('authenticatorConfig', []):
    role = cfg.get('config', {}).get('condUserRole')
    if role is not None and role not in realm_roles and role not in client_roles:
        problems.append(f'authenticator config "{cfg.get("alias")}" names a role the export lacks: {role}')

for line in problems:
    print(f'FAIL {line}')
print(f'realm export roles: {len(problems)} problem(s)' if problems else 'realm export roles: PASS')
sys.exit(1 if problems else 0)
