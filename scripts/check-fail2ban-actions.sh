#!/bin/bash
# Fails when actionban or actionunban in an iptables action file hides a
# failure, so fail2ban counts a ban that never happened (stack#5).
# actionstart and actionstop stay idempotent and may keep `|| true`.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="${1:-$ROOT/fail2ban/config/fail2ban/action.d}"
status=0

for file in "$DIR"/iptables-allports.local "$DIR"/iptables-multiport.local; do
  if [ ! -f "$file" ]; then
    echo "FAIL: $file is missing" >&2
    status=1
    continue
  fi
  # Print the lines of each actionban/actionunban block, including indented continuations.
  bad=$(awk '
    /^[A-Za-z_]+[ \t]*=/ { inblock = ($1 == "actionban" || $1 == "actionunban") }
    /^[ \t]*$/ { next }
    /^[ \t]*#/ { next }
    inblock && (/\|\|[ \t]*true/ || /2>[ \t]*\/dev\/null/) { print FILENAME ":" FNR ": " $0 }
  ' "$file")
  if [ -n "$bad" ]; then
    echo "FAIL: ban or unban hides a failure:" >&2
    echo "$bad" >&2
    status=1
  fi
done

if [ "$status" = 0 ]; then
  echo "OK: actionban and actionunban report failures in both iptables action files"
fi
exit "$status"
