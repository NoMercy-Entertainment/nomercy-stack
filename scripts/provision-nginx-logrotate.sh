#!/bin/bash
# infra/nomercy-stack/scripts/provision-nginx-logrotate.sh
#
# Installs the repo's logrotate config for the bind-mounted nginx logs
# (logs/nginx/access.log, error.log, debug.log) as
# /etc/logrotate.d/nomercy-nginx. Host logrotate already runs via the
# system's daily cron (see /etc/cron.daily/logrotate); this just adds our
# stanza to it.
#
# Idempotent: only writes if the installed file differs from the repo copy.
#
# Run on the target host as root:
#   /opt/nomercy-stack/scripts/provision-nginx-logrotate.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/scripts/logrotate/nomercy-nginx.conf"
DEST="/etc/logrotate.d/nomercy-nginx"

if [ ! -f "$SRC" ]; then
    echo "ERROR: $SRC not found" >&2
    exit 1
fi

if [ -f "$DEST" ] && cmp -s "$SRC" "$DEST"; then
    echo "OK: $DEST already matches $SRC, nothing to do"
    exit 0
fi

install -m 0644 "$SRC" "$DEST"
echo "Installed $SRC -> $DEST"

logrotate -d "$DEST" >/dev/null
echo "logrotate config parses cleanly (dry-run OK)"
