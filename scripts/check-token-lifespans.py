#!/usr/bin/env python3
"""Fail when a Keycloak access token lifespan is above its approved ceiling.

keycloak/token-lifespan-ceiling.json holds the approved realm values. A client
may not outlive the realm value, except the cast receiver, which has its own cap.
Arguments, all optional: realm export, cast receiver client, ceiling file.
"""
import json
import sys
from pathlib import Path

KEYCLOAK = Path(__file__).resolve().parent.parent / 'keycloak'
DEFAULTS = ('realm-export.json', 'cast-receiver-client.json', 'token-lifespan-ceiling.json')
REALM_KEYS = ('accessTokenLifespan', 'accessTokenLifespanForImplicitFlow')
CLIENT_ATTRIBUTE = 'access.token.lifespan'
CAST_RECEIVER = 'nomercy-cast-receiver'
CAST_RECEIVER_CEILING = 43200

paths = [Path(sys.argv[i + 1]) if len(sys.argv) > i + 1 else KEYCLOAK / name for i, name in enumerate(DEFAULTS)]
realm, cast_client, ceiling = (json.loads(path.read_text(encoding='utf-8')) for path in paths)

failures = 0


def judge(label, value, limit):
    global failures
    try:
        passed = int(value) <= int(limit)
    except (TypeError, ValueError):
        passed = False
    failures += 0 if passed else 1
    print(f'{"PASS" if passed else "FAIL"} {label}: value {value}, ceiling {limit}')


for key in REALM_KEYS:
    judge(f'realm {key}', realm.get(key), ceiling.get(key))

realm_lifespan = realm.get('accessTokenLifespan')
for client in [*realm.get('clients', []), cast_client]:
    value = client.get('attributes', {}).get(CLIENT_ATTRIBUTE)
    if value in (None, ''):
        continue
    client_id = client.get('clientId')
    limit = CAST_RECEIVER_CEILING if client_id == CAST_RECEIVER else realm_lifespan
    judge(f'client {client_id} {CLIENT_ATTRIBUTE}', value, limit)

print(f'target: {ceiling.get("target")}')
print(f'token lifespans: {failures} problem(s)' if failures else 'token lifespans: PASS')
sys.exit(1 if failures else 0)
