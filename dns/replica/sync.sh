#!/bin/sh
# Mirrors ns1's dynamic.db every 3 s. Replaces the local file only when the download
# is non-empty, looks like a zone, and differs from what is already there.
set -u
OUT=/zones/dynamic.db
TMP=/zones/.dynamic.db.new
INTERVAL="${SYNC_INTERVAL:-3}"
# The token goes to curl through a header file only this user can read, never on the
# command line, where any user on the host can see it (stack#8).
AUTH=$(umask 077 && mktemp)
trap 'rm -f "$AUTH"' EXIT
printf 'Authorization: Bearer %s\n' "$TXT_UPDATER_TOKEN" > "$AUTH"

while true; do
    if curl -fsS --max-time 5 -H @"$AUTH" \
        -o "$TMP" "$ZONE_URL" 2>/dev/null; then
        if [ -s "$TMP" ] && grep SOA "$TMP" > /dev/null; then
            if ! cmp -s "$TMP" "$OUT"; then
                mv "$TMP" "$OUT"
                echo "zone updated $(date -u +%H:%M:%S)"
            fi
        else
            echo "ignored empty or non-zone response" >&2
        fi
    else
        echo "fetch failed" >&2
    fi
    rm -f "$TMP"
    sleep "$INTERVAL"
done
