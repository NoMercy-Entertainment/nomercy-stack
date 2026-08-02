#!/bin/bash
# Applies the NoMercyTV login/passkey realm configuration through the Keycloak admin REST API,
# authenticating as the nomercy-api service account rather than a human admin session.
#
# This supersedes apply-login-config.sh for the realm half. That script drove kcadm against a
# "Forms" subflow, and neither the live prod nor the live dev realm has one — both were bound to
# a custom "passwordless-email" flow. The fix on both was to bind the built-in "browser" flow,
# whose forms subflow is already auth-username-password-form plus a correctly gated conditional
# OTP. Keep apply-login-config.sh only for a realm actually shaped like the committed export.
#
# Reads before it writes and prints both, because the live realms have repeatedly turned out not
# to match the committed export.
#
# Everything is piped rather than staged through temp files: run from Git Bash on Windows, curl
# writes /tmp to the MSYS root while native python reads it as C:\tmp, so a file written by one
# is invisible to the other and the step no-ops without failing.
#
# Usage:
#   ./apply-realm-config.sh <auth-base-url> <env-file>
#   ./apply-realm-config.sh https://auth.nomercy.tv     /opt/nomercy-stack/website/data/.env
#   ./apply-realm-config.sh https://auth-dev.nomercy.tv ./website/data/.env
#
# The env file must contain KEYCLOAK_ADMIN_CLIENT_ID and KEYCLOAK_ADMIN_CLIENT_SECRET. The secret
# is never echoed and never leaves the machine the script runs on.

set -euo pipefail

BASE="${1:?auth base url required, e.g. https://auth.nomercy.tv}"
ENV_FILE="${2:?path to an env file holding KEYCLOAK_ADMIN_CLIENT_ID/SECRET}"
REALM="${REALM:-NoMercyTV}"
ADMIN="$BASE/admin/realms/$REALM"

CLIENT_ID=$(grep -E '^KEYCLOAK_ADMIN_CLIENT_ID=' "$ENV_FILE" | cut -d= -f2- | tr -d '"' | tr -d "'")
CLIENT_SECRET=$(grep -E '^KEYCLOAK_ADMIN_CLIENT_SECRET=' "$ENV_FILE" | cut -d= -f2- | tr -d '"' | tr -d "'")
: "${CLIENT_ID:?KEYCLOAK_ADMIN_CLIENT_ID missing from $ENV_FILE}"
: "${CLIENT_SECRET:?KEYCLOAK_ADMIN_CLIENT_SECRET missing from $ENV_FILE}"

TOKEN=$(curl -s --max-time 20 \
  -d 'grant_type=client_credentials' \
  -d "client_id=$CLIENT_ID" \
  --data-urlencode "client_secret=$CLIENT_SECRET" \
  "$BASE/realms/$REALM/protocol/openid-connect/token" \
  | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))")
[ -n "$TOKEN" ] || { echo "could not obtain a service-account token from $BASE" >&2; exit 1; }

get()  { curl -s --max-time 30 -H "Authorization: Bearer $TOKEN" "$ADMIN$1"; }
put()  { curl -s --max-time 30 -X PUT -H "Authorization: Bearer $TOKEN" \
           -H 'Content-Type: application/json' -d @- "$ADMIN$1" -o /dev/null -w "%{http_code}"; }

echo "==> $BASE  realm $REALM"

# The built-in browser flow must exist and carry the combined form, or binding to it would put
# users on a screen that cannot authenticate them.
get '/authentication/flows/browser/executions' | python3 -c "
import json, sys
d = json.load(sys.stdin)
if not isinstance(d, list):
    print('  cannot read the browser flow:', d); sys.exit(1)
combined = [e for e in d if e.get('providerId') == 'auth-username-password-form']
if not combined:
    print('  browser flow has no auth-username-password-form - refusing to bind'); sys.exit(1)
print('  browser flow ok: auth-username-password-form is', combined[0]['requirement'])
"

KEYS="browserFlow webAuthnPolicyPasswordlessPasskeysEnabled webAuthnPolicyPasswordlessRpId webAuthnPolicyPasswordlessRpEntityName webAuthnPolicyPasswordlessAuthenticatorAttachment webAuthnPolicyPasswordlessRequireResidentKey webAuthnPolicyPasswordlessUserVerificationRequirement"

REALM_JSON=$(get '')
echo "  BEFORE"
printf '%s' "$REALM_JSON" | KEYS="$KEYS" python3 -c "
import json, os, sys
d = json.load(sys.stdin)
for k in os.environ['KEYS'].split(): print('    %-54s %r' % (k, d.get(k)))
"

STATUS=$(printf '%s' "$REALM_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
d['browserFlow'] = 'browser'
# rpId must be the registrable parent domain, not the auth host, or a passkey created in the
# browser is scoped to auth.* alone and the native apps can never present it. Changing this
# orphans passkeys registered under the previous value; they have to be registered again.
for p in ('webAuthnPolicy', 'webAuthnPolicyPasswordless'):
    d[p + 'RpId'] = 'nomercy.tv'
    d[p + 'RpEntityName'] = 'NoMercy'
    # 'cross-platform' restricts WebAuthn to roaming security keys and makes browsers refuse
    # Touch ID, Windows Hello and Android screen lock. Unset accepts both kinds.
    d[p + 'AuthenticatorAttachment'] = 'not specified'
    # Conditional UI only offers DISCOVERABLE credentials, so a passkey that is not resident is
    # never surfaced in the autofill prompt. User verification is what makes it a PIN/biometric.
    d[p + 'RequireResidentKey'] = 'Yes'
    d[p + 'UserVerificationRequirement'] = 'required'
d['webAuthnPolicyPasswordlessPasskeysEnabled'] = True
json.dump(d, sys.stdout)
" | put '')
echo "  PUT realm HTTP $STATUS"

echo "  AFTER"
get '' | KEYS="$KEYS" python3 -c "
import json, os, sys
d = json.load(sys.stdin)
for k in os.environ['KEYS'].split(): print('    %-54s %r' % (k, d.get(k)))
"

# Consent presentation: the scope had no consent text so the raw scope id leaked onto the screen,
# and the clients had no display name so they showed their bare clientId.
SCOPE_ID=$(get '/client-scopes' | python3 -c "
import json, sys
m = [s for s in json.load(sys.stdin) if s['name'] == 'client-roles-nomercy-ui']
print(m[0]['id'] if m else '')
")
if [ -n "$SCOPE_ID" ]; then
  ST=$(get "/client-scopes/$SCOPE_ID" | python3 -c "
import json, sys
d = json.load(sys.stdin)
d.setdefault('attributes', {})['consent.screen.text'] = '\${clientRolesScopeConsentText}'
d['attributes']['display.on.consent.screen'] = 'true'
json.dump(d, sys.stdout)
" | put "/client-scopes/$SCOPE_ID")
  echo "  scope client-roles-nomercy-ui HTTP $ST"
fi

set_client_name() {
  local CID="$1" NAME="$2" BODY UUID ST
  BODY=$(get "/clients?clientId=$CID")
  UUID=$(printf '%s' "$BODY" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d[0]['id'] if d else '')
")
  [ -n "$UUID" ] || { echo "  client $CID not present"; return; }
  ST=$(printf '%s' "$BODY" | NM_NAME="$NAME" python3 -c "
import json, os, sys
d = json.load(sys.stdin)[0]
d['name'] = os.environ['NM_NAME']
json.dump(d, sys.stdout)
" | put "/clients/$UUID")
  echo "  client $CID -> \"$NAME\" HTTP $ST"
}
set_client_name nomercy-ui "NoMercy"
set_client_name nomercy-server "NoMercy Media Server"

echo "==> verifying through the public login url"
curl -s --max-time 25 "$BASE/realms/$REALM/protocol/openid-connect/auth?client_id=nomercy-ui&redirect_uri=https%3A%2F%2Fnomercy.tv%2F&response_type=code&scope=openid" \
  | grep -oE 'id="(username|password|authenticateWebAuthnButton)"|autocomplete="username webauthn"|rpId : "[^"]*"|userVerification : "[^"]*"' \
  | sort -u | sed 's/^/    /'
