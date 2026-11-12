#!/usr/bin/env bash
# Applies proxy/nginx.conf to the running proxy with no restart.
# nginx.conf is a single-file bind mount: a git pull writes a new inode and the
# container keeps reading the old one, so the content is written into the mount.
# Usage: scripts/apply-proxy-config.sh [config file]   (default: proxy/nginx.conf)
set -euo pipefail
cd "$(dirname "$0")/.."

PROXY_CONTAINER="${APP_NAME:-nomercy.tv}-proxy"
CONFIG="${1:-proxy/nginx.conf}"
LIVE=/etc/nginx/nginx.conf
BACKUP="/tmp/nginx.conf.before-$(date +%s)"

[ -f "$CONFIG" ] || { echo "ERROR: $CONFIG not found." >&2; exit 1; }

docker exec "$PROXY_CONTAINER" cp "$LIVE" "$BACKUP"
docker exec -i "$PROXY_CONTAINER" sh -c "cat > $LIVE" < "$CONFIG"

if ! docker exec "$PROXY_CONTAINER" nginx -t; then
  docker exec "$PROXY_CONTAINER" sh -c "cat $BACKUP > $LIVE"
  docker exec "$PROXY_CONTAINER" nginx -t
  echo "ROLLBACK: nginx -t failed on $CONFIG; the previous config is back and nginx was not reloaded." >&2
  exit 1
fi

docker exec "$PROXY_CONTAINER" nginx -s reload
want=$(md5sum < "$CONFIG" | cut -d' ' -f1)
live=$(docker exec "$PROXY_CONTAINER" md5sum "$LIVE" | cut -d' ' -f1)
[ "$want" = "$live" ] || { echo "ERROR: the live config differs from $CONFIG." >&2; exit 1; }
echo "Applied $CONFIG to $PROXY_CONTAINER and reloaded (md5 $live). Backup: $BACKUP in the container."
