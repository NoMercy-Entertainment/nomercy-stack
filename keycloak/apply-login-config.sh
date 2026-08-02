#!/bin/bash
# Applies the one-screen login + consent + passkey configuration to a NoMercyTV realm.
#
# Every step was verified end to end on 2026-08-02 against a throwaway Keycloak 26.6.4
# with this realm imported: one POST of username+password returns an authorization code,
# the passkey button renders, and no user is forced into passkey enrolment.
#
# Idempotent — safe to re-run. Reads the admin password from KC_ADMIN_PASSWORD so no
# credential is ever passed on the command line.
#
# Usage:
#   KC_ADMIN_PASSWORD=... ./apply-login-config.sh <container> [admin-user] [realm]
#   KC_ADMIN_PASSWORD=... ./apply-login-config.sh nomercy.tv-keycloak admin NoMercyTV

set -euo pipefail

CONTAINER="${1:?container name required, e.g. nomercy.tv-keycloak}"
ADMIN_USER="${2:-admin}"
REALM="${3:-NoMercyTV}"
: "${KC_ADMIN_PASSWORD:?export KC_ADMIN_PASSWORD before running}"

kc() { docker exec -i "$CONTAINER" /opt/keycloak/bin/kcadm.sh "$@"; }

# Keycloak has no PUT on /authentication/executions/{id}; a requirement change has to go
# through the owning flow. kcadm's `update authentication/executions/{id}` 404s.
# The payload is piped straight into the container rather than staged through a host temp
# file: on Windows, Git Bash and native Python resolve /tmp to different directories, so a
# file written by one is invisible to the other and the update silently no-ops.
set_requirement() {
  local FLOW="$1" MATCH="$2" REQUIREMENT="$3"
  local PAYLOAD
  PAYLOAD=$(kc get "authentication/flows/$FLOW/executions" -r "$REALM" 2>/dev/null | python3 -c "
import sys, json
match, requirement = '''$MATCH''', '''$REQUIREMENT'''
e = next((x for x in json.load(sys.stdin)
          if x.get('providerId') == match or x.get('displayName') == match), None)
if e:
    e['requirement'] = requirement
    print(json.dumps(e))
")
  if [ -z "$PAYLOAD" ]; then
    echo "    WARNING: '$MATCH' not found in flow '$FLOW' — nothing changed" >&2
    return 1
  fi
  printf '%s' "$PAYLOAD" | docker exec -i "$CONTAINER" sh -c 'cat > /tmp/nm-exec.json'
  kc update "authentication/flows/$FLOW/executions" -r "$REALM" -f /tmp/nm-exec.json
  docker exec "$CONTAINER" rm -f /tmp/nm-exec.json
  echo "    $MATCH -> $REQUIREMENT"
}

echo "==> authenticating against $CONTAINER"
kc config credentials --server http://localhost:8080 --realm master \
  --user "$ADMIN_USER" --password "$KC_ADMIN_PASSWORD" >/dev/null

# ---------------------------------------------------------------------------
# 1. One screen: the combined form replaces the email-only step.
#
# auth-username-password-form renders login.ftl with email + password together and
# natively delegates to WebAuthnConditionalUIAuthenticator, so it carries passkeys
# with no custom provider. 'No Password' and 'Password Fallback' existed only to
# reach a password on a second screen, so they go with it.
# ---------------------------------------------------------------------------
echo "==> rebuilding the Forms flow"
for TARGET in auth-username-form "No Password" "Password Fallback"; do
  ID=$(kc get "authentication/flows/Forms/executions" -r "$REALM" 2>/dev/null | python3 -c "
import sys, json
t = '''$TARGET'''
print(next((e['id'] for e in json.load(sys.stdin)
            if e.get('providerId') == t or e.get('displayName') == t), ''))
")
  if [ -n "$ID" ]; then
    kc delete "authentication/executions/$ID" -r "$REALM" && echo "    removed $TARGET"
  fi
done

# Count exact providerId matches rather than grepping the raw payload: a substring test also
# matches unrelated JSON and, when it misfires, this adds a SECOND combined form. Two REQUIRED
# username-password executions means the user is asked for their password twice — the login
# succeeds, then immediately prompts again.
count_form() {
  kc get "authentication/flows/Forms/executions" -r "$REALM" 2>/dev/null | python3 -c "
import sys, json
print(sum(1 for e in json.load(sys.stdin) if e.get('providerId') == 'auth-username-password-form'))
"
}

HAVE=$(count_form)
if [ "${HAVE:-0}" -eq 0 ]; then
  kc create "authentication/flows/Forms/executions/execution" -r "$REALM" \
    -s provider=auth-username-password-form
  echo "    added auth-username-password-form"
fi

# Drop any duplicate beyond the first, so re-running can never stack another prompt.
while [ "$(count_form)" -gt 1 ]; do
  DUP=$(kc get "authentication/flows/Forms/executions" -r "$REALM" 2>/dev/null | python3 -c "
import sys, json
ids = [e['id'] for e in json.load(sys.stdin) if e.get('providerId') == 'auth-username-password-form']
print(ids[-1] if len(ids) > 1 else '')
")
  [ -z "$DUP" ] && break
  kc delete "authentication/executions/$DUP" -r "$REALM"
  echo "    removed a duplicate auth-username-password-form"
done

set_requirement Forms auth-username-password-form REQUIRED

# ---------------------------------------------------------------------------
# 2. 2FA stays DISABLED — deliberately, not by omission.
#
# It sat as ALTERNATIVE beside a REQUIRED execution, and Keycloak ignores
# ALTERNATIVEs at a level that has a REQUIRED, so it has never run in production.
# Making it CONDITIONAL makes conditional-user-configured evaluate true for users
# with no second factor (an execution permitting user setup counts as satisfiable),
# which forces every passkey-less user through webauthn-register after login.
# Shipping it DISABLED preserves today's real behaviour. Enabling a working second
# factor is a separate change that needs its own testing.
# ---------------------------------------------------------------------------
echo "==> pinning 2FA to DISABLED"
set_requirement Forms 2FA DISABLED

# ---------------------------------------------------------------------------
# 3. Passkeys.
#
# webAuthnPolicyPasswordlessPasskeysEnabled is the switch that sets
# enableWebAuthnConditionalUI and renders the passkey button. It is not an
# authenticator config option and is absent from realm exports until set.
#
# attachment: 'cross-platform' restricts WebAuthn to roaming authenticators (USB/NFC
# keys) and makes browsers refuse Touch ID, Face ID, Windows Hello and Android screen
# lock — the actual cause of passkeys being unusable. Clearing it accepts both.
#
# rpId: empty binds passkeys to the exact origin host. nomercy.tv scopes them across
# app./auth./nomercy.tv and is required for native Android/iOS association via
# assetlinks.json / apple-app-site-association. Passkeys registered under the old
# value stop working and must be re-registered.
# ---------------------------------------------------------------------------
echo "==> enabling passkeys and fixing the WebAuthn policy"
kc update "realms/$REALM" \
  -s webAuthnPolicyPasswordlessPasskeysEnabled=true \
  -s 'webAuthnPolicyAuthenticatorAttachment=not specified' \
  -s 'webAuthnPolicyPasswordlessAuthenticatorAttachment=not specified' \
  -s webAuthnPolicyRpEntityName=NoMercy \
  -s webAuthnPolicyPasswordlessRpEntityName=NoMercy \
  -s webAuthnPolicyRpId=nomercy.tv \
  -s webAuthnPolicyPasswordlessRpId=nomercy.tv

# ---------------------------------------------------------------------------
# 4. Consent screen. The raw scope id leaked because this scope had no consent text;
#    clients showed their bare clientId because name was empty.
# ---------------------------------------------------------------------------
echo "==> fixing consent presentation"
SCOPE_ID=$(kc get client-scopes -r "$REALM" --fields id,name 2>/dev/null | python3 -c "
import sys, json
print(next((s['id'] for s in json.load(sys.stdin)
            if s['name'] == 'client-roles-nomercy-ui'), ''))
")
if [ -n "$SCOPE_ID" ]; then
  kc update "client-scopes/$SCOPE_ID" -r "$REALM" \
    -s 'attributes."consent.screen.text"=${clientRolesScopeConsentText}' \
    -s 'attributes."display.on.consent.screen"=true'
  echo "    client-roles-nomercy-ui now shows a readable label"
fi

set_client_name() {
  local CLIENT_ID="$1" DISPLAY="$2"
  local ID
  ID=$(kc get clients -r "$REALM" -q "clientId=$CLIENT_ID" --fields id 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d[0]['id'] if d else '')
")
  [ -n "$ID" ] && kc update "clients/$ID" -r "$REALM" -s "name=$DISPLAY" && echo "    $CLIENT_ID -> \"$DISPLAY\""
}
set_client_name nomercy-ui "NoMercy"
set_client_name nomercy-server "NoMercy Media Server"

echo
echo "==> done. Verify with a real login:"
echo "    https://<auth-host>/realms/$REALM/protocol/openid-connect/auth?client_id=nomercy-ui&redirect_uri=<uri>&response_type=code&scope=openid&theme=e5484d"
echo "    Expect one screen with email + password + passkey, and no forced enrolment."
