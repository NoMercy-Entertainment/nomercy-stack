#!/bin/sh
# Keeps the A record of this name server equal to the home public IPv4.
# Reads CF_TOKEN, CF_ZONE_ID and CF_RECORD_NAME from the environment (token limited to DNS edit on one zone).
# Changes the record only when the address looks valid and differs. ONCE=1 runs a single pass (used by the test).
set -u
CF_API="${CF_API:-https://api.cloudflare.com/client/v4}"
IP_URL="${IP_URL:-https://api.ipify.org}"
INTERVAL="${SYNC_INTERVAL:-60}"
# The token goes to curl through a header file only this user can read, never on the
# command line, where any user on the host can see it (stack#8).
AUTH=$(umask 077 && mktemp)
trap 'rm -f "$AUTH"' EXIT
printf 'Authorization: Bearer %s\n' "$CF_TOKEN" > "$AUTH"

pass() {
    ip=$(curl -fsS --max-time 8 "$IP_URL" 2>/dev/null | tr -d ' \r\n')
    case "$ip" in
        [0-9]*.[0-9]*.[0-9]*.[0-9]*) ;;
        *) echo "no valid public address: skipped" >&2; return 1 ;;
    esac
    rec=$(curl -fsS --max-time 10 -H @"$AUTH" \
        "$CF_API/zones/${CF_ZONE_ID}/dns_records?type=A&name=${CF_RECORD_NAME}" 2>/dev/null) || { echo "cloudflare read failed" >&2; return 1; }
    id=$(printf '%s' "$rec" | jq -r '.result[0].id // empty')
    cur=$(printf '%s' "$rec" | jq -r '.result[0].content // empty')
    if [ -z "$id" ]; then echo "record ${CF_RECORD_NAME} not found: left alone" >&2; return 1; fi
    if [ "$cur" = "$ip" ]; then return 0; fi
    out=$(curl -fsS --max-time 10 -X PATCH -H @"$AUTH" -H "Content-Type: application/json" \
        --data "{\"content\":\"$ip\"}" "$CF_API/zones/${CF_ZONE_ID}/dns_records/$id" 2>/dev/null) || { echo "cloudflare update failed" >&2; return 1; }
    if [ "$(printf '%s' "$out" | jq -r '.success')" = "true" ]; then
        echo "record ${CF_RECORD_NAME} changed $cur -> $ip at $(date -u +%H:%M:%S)"
    else
        echo "cloudflare refused the update" >&2
        return 1
    fi
}

if [ "${ONCE:-0}" = "1" ]; then pass; exit $?; fi
while true; do
    pass || true
    sleep "$INTERVAL"
done
