#!/usr/bin/env python3
"""Fail when the realm requires a field the registration form never asks for.

Between 21 May and 2 August 2026 this pair was inconsistent and email-and-password
registration created zero accounts on production. The realm marked firstName and
lastName required for the user role; register.ftl next to it rendered email,
password, password-confirm, termsAccepted and username, and never a name field. A
new user submitted every field on the page and Keycloak rejected the submission for
two fields that are not on it, clearing the password boxes on re-render so it read
as a password problem. Google signups were unaffected the whole time, because a
brokered login never renders that form, which is what kept the failure quiet.

Both halves were committed, reviewed and deployed. Nothing compared them, because
they belong to different tools and the mismatch is only visible from the outside.

Exits non-zero with the offending field names.
"""

import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
REALM = HERE / "keycloak" / "realm-export.json"
FORM = HERE / "keycloak" / "themes" / "NoMercy" / "login" / "register.ftl"

# Rendered by Keycloak's own machinery rather than by our template, so their absence
# from register.ftl is not a defect.
PROVIDED_BY_KEYCLOAK = {"username"}


def required_attributes(realm_path: Path) -> set[str]:
    realm = json.loads(realm_path.read_text(encoding="utf-8"))

    components = realm.get("components", {})
    profiles = components.get("org.keycloak.userprofile.UserProfileProvider", [])
    if not profiles:
        sys.exit(f"{realm_path}: no declarative user profile component, cannot check")

    config = profiles[0].get("config", {})
    pieces = sorted(
        (key for key in config if key.startswith("config-piece-")),
        key=lambda key: int(key.rsplit("-", 1)[1]),
    )
    if not pieces:
        sys.exit(f"{realm_path}: user profile component carries no config pieces")

    raw = "".join(config[piece][0] for piece in pieces)
    profile = json.loads(raw)

    return {
        attribute["name"]
        for attribute in profile.get("attributes", [])
        if attribute.get("required")
    }


def rendered_fields(form_path: Path) -> set[str]:
    markup = form_path.read_text(encoding="utf-8")
    return set(re.findall(r'name="([A-Za-z][A-Za-z0-9_-]*)"', markup))


def main() -> int:
    for path in (REALM, FORM):
        if not path.exists():
            sys.exit(f"missing {path}")

    required = required_attributes(REALM)
    rendered = rendered_fields(FORM) | PROVIDED_BY_KEYCLOAK

    missing = sorted(required - rendered)

    if missing:
        print("Registration form does not offer every field the realm requires.")
        print()
        print(f"  realm requires : {', '.join(sorted(required))}")
        print(f"  form renders   : {', '.join(sorted(rendered))}")
        print(f"  unreachable    : {', '.join(missing)}")
        print()
        print("Every new signup will fail with a 'field required' error against an")
        print("input that is not on the page. Either render the field in register.ftl")
        print("or drop its required flag from the realm export.")
        return 1

    print(f"Registration form offers every required field: {', '.join(sorted(required))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
