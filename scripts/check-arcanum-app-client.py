#!/usr/bin/env python3
"""Fail when the realm export lacks the Arcanum app client in its hardened shape.

The Arcanum phone and desktop apps sign in with a public PKCE client and take their
authority from two client roles. A client that allows direct grants, the implicit
flow or a service account, or that does not force S256, weakens the strong-auth
design in the Arcanum slice 5 card. Role assignments are live data and never live
in this export, so the export must carry no users.

Exits non-zero with every defect found.
"""

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
REALM = HERE / "keycloak" / "realm-export.json"

CLIENT_ID = "arcanum-app"
REDIRECT_URIS = {"tv.nomercy.arcanum:/oauth", "http://127.0.0.1/*"}
ROLES = {"arcanum:owner", "arcanum:operator"}


def defects(realm: dict) -> list[str]:
    found: list[str] = []
    clients = [c for c in realm.get("clients", []) if c.get("clientId") == CLIENT_ID]
    if len(clients) != 1:
        return [f"expected one client {CLIENT_ID}, found {len(clients)}"]
    client = clients[0]

    expected = {
        "enabled": True,
        "publicClient": True,
        "standardFlowEnabled": True,
        "implicitFlowEnabled": False,
        "directAccessGrantsEnabled": False,
        "serviceAccountsEnabled": False,
        "bearerOnly": False,
    }
    for key, want in expected.items():
        if client.get(key) is not want:
            found.append(f"{key} is {client.get(key)!r}, want {want!r}")

    pkce = client.get("attributes", {}).get("pkce.code.challenge.method")
    if pkce != "S256":
        found.append(f"pkce.code.challenge.method is {pkce!r}, want 'S256'")

    uris = set(client.get("redirectUris", []))
    if uris != REDIRECT_URIS:
        found.append(f"redirectUris is {sorted(uris)}, want {sorted(REDIRECT_URIS)}")

    names = {r["name"] for r in realm.get("roles", {}).get("client", {}).get(CLIENT_ID, [])}
    if names != ROLES:
        found.append(f"client roles are {sorted(names)}, want {sorted(ROLES)}")

    if realm.get("users"):
        found.append("the export carries users; role assignments are live data only")
    return found


def main() -> int:
    problems = defects(json.loads(REALM.read_text(encoding="utf-8")))
    for problem in problems:
        print(f"FAIL {problem}")
    if problems:
        return 1
    print(f"ok {CLIENT_ID}: public, PKCE S256, no direct grants, roles {sorted(ROLES)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
