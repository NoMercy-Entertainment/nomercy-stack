#!/bin/bash
# Blue-green deploy for the nomercy-tv website container.
#
# Brings up the idle color (website-blue or website-green), health-gates it
# (docker healthcheck + a real /up curl from inside the container), and only
# then flips the nginx upstream to it with `nginx -s reload` — a graceful
# reload finishes in-flight requests on the old upstream on the old worker
# processes and sends new connections to the new one; the listener socket on
# :80/:443 never closes, so there is no refused-connection window. The
# previous color is drained and stopped, not removed, so it becomes the next
# deploy's idle target.
#
# If the idle color never becomes healthy, this script leaves the currently
# active color serving and exits non-zero. It never switches traffic to an
# unhealthy target.
#
# EXPAND/CONTRACT REQUIREMENT: blue and green run against the SAME database
# during the health-gate + drain window (both containers, one still serving
# live traffic). Any migration shipped in a release deployed through this
# script MUST be backward compatible with the code still running in the
# outgoing color for that whole window — additive columns/tables/indexes
# only. A breaking schema change (rename, drop, type change, NOT NULL on an
# existing column) needs to be split into an expand deploy (add + dual
# read/write) shipped and soaked first, then a later contract deploy (remove
# the old shape) once you've confirmed no color is still reading/writing it.
# This script does not detect or block breaking migrations — that is a
# migration-review responsibility, not an infra one. See README.md.
#
# Idempotent: safe to re-run. State lives in two files, both server-local and
# gitignored: website/.active-color (which color is live) and
# proxy/sites/upstream-website.conf (what nginx currently points at, kept in
# sync with the marker by this script).
#
# Usage: ./scripts/deploy-website.sh
# Run from anywhere; paths below are absolute to the stack root.

set -euo pipefail

STACK_DIR="/opt/nomercy-stack"
WEBSITE_DIR="$STACK_DIR/website"
ACTIVE_COLOR_FILE="$WEBSITE_DIR/.active-color"
UPSTREAM_CONF="$STACK_DIR/proxy/sites/upstream-website.conf"
UPSTREAM_DEFAULT="$STACK_DIR/proxy/sites/upstream-website.conf.default"
PROXY_CONTAINER="${APP_NAME:-nomercy.tv}-proxy"
LEGACY_CONTAINER="${APP_NAME:-nomercy.tv}-website"
HEALTH_TIMEOUT_TRIES=24    # 24 * 5s = 120s
HEALTH_TIMEOUT_SLEEP=5
DRAIN_SECONDS=15

cd "$STACK_DIR"

echo "== nomercy-tv blue-green deploy =="

# --- bootstrap: first run under blue-green has no upstream file yet ---
if [ ! -f "$UPSTREAM_CONF" ]; then
  echo "No live upstream conf yet — bootstrapping from default (website-blue)."
  cp "$UPSTREAM_DEFAULT" "$UPSTREAM_CONF"
fi

# --- one-time cutover: adopt the pre-blue-green single container as blue ---
if [ ! -f "$ACTIVE_COLOR_FILE" ]; then
  if docker inspect "$LEGACY_CONTAINER" >/dev/null 2>&1; then
    echo "ONE-TIME CUTOVER: adopting legacy '$LEGACY_CONTAINER' as website-blue."
    echo "This one recreate is NOT zero-downtime (same class of blip as the old"
    echo "single-container deploy) — it reuses the same ./data bind mount and"
    echo "vendor/node_modules volumes, so it comes back in a few seconds. Every"
    echo "deploy after this one is a real blue-green switch."
    docker compose stop website >/dev/null 2>&1 || true
    docker compose up -d --no-deps website-blue
  fi
  echo "blue" > "$ACTIVE_COLOR_FILE"
fi

active=$(cat "$ACTIVE_COLOR_FILE")
case "$active" in
  blue) idle="green" ;;
  green) idle="blue" ;;
  *)
    echo "ERROR: unrecognized active color '$active' in $ACTIVE_COLOR_FILE" >&2
    exit 1
    ;;
esac

idle_service="website-${idle}"
active_service="website-${active}"
idle_container="${APP_NAME:-nomercy.tv}-website-${idle}"

if [ "$idle" = "blue" ]; then
  IDLE_DATA_DIR="$WEBSITE_DIR/data"
else
  IDLE_DATA_DIR="$WEBSITE_DIR/data-green"
fi

echo "Active color: $active   Deploying to idle color: $idle"

# --- one-time checkout bootstrap for the green color ---
if [ "$idle" = "green" ] && [ ! -d "$IDLE_DATA_DIR/.git" ]; then
  echo "First-ever green deploy: cloning data-green from the existing checkout."
  git clone --origin origin "$WEBSITE_DIR/data" "$IDLE_DATA_DIR"
  git -C "$IDLE_DATA_DIR" remote set-url origin "$(git -C "$WEBSITE_DIR/data" remote get-url origin)"
fi

# --- update the idle color's code checkout to the release commit ---
git -C "$IDLE_DATA_DIR" fetch origin master
git -C "$IDLE_DATA_DIR" reset --hard origin/master

# --- build only the idle color's image (active color's image/container is
#     never touched by this run) ---
docker compose build --no-cache "$idle_service"

# --- clear a stale exited container with this name, then start idle ---
docker ps -aq --filter "status=exited" --filter "name=${idle_container}" | xargs -r docker rm -f
docker compose up -d --no-deps "$idle_service"

# --- known volume-shadow workaround (see website/config/start.sh): the named
#     vendor volume persists across recreates, so a stale autoload can shadow
#     the freshly-built image's stash on a non-first boot. Re-dump the optimized
#     autoload against the reset checkout before the health gate. Assets are NOT
#     rebuilt here — start.sh restores the image's baked public/build, keeping
#     the memory-heavy `yarn build` off the live host (it was OOM-killing the
#     deploy when run alongside the other color and the rest of the stack). ---
docker compose exec -T "$idle_service" su -s /bin/bash www -c "cd /var/www/html && composer dump-autoload --optimize"

# --- health gate: never switch traffic to an unhealthy idle color ---
echo "Waiting for $idle_container to become healthy..."
healthy=0
status="missing"
for _ in $(seq 1 "$HEALTH_TIMEOUT_TRIES"); do
  status=$(docker inspect --format '{{.State.Health.Status}}' "$idle_container" 2>/dev/null || echo missing)
  if [ "$status" = "healthy" ]; then
    healthy=1
    break
  fi
  sleep "$HEALTH_TIMEOUT_SLEEP"
done

if [ "$healthy" != "1" ]; then
  echo "ERROR: $idle_container did not become healthy within timeout (last status: $status)." >&2
  docker logs --tail 60 "$idle_container" || true
  echo "ROLLBACK: leaving '$active' serving, nginx untouched. $idle_container left" >&2
  echo "running (not removed) for inspection — stop it once diagnosed, then re-run" >&2
  echo "this script to retry." >&2
  exit 1
fi

code=$(docker exec "$idle_container" curl -s -o /dev/null -w '%{http_code}' -m 10 http://127.0.0.1:8080/up || echo 000)
if [ "$code" != "200" ]; then
  echo "ERROR: /up returned $code on $idle_container after deploy." >&2
  docker logs --tail 60 "$idle_container" || true
  echo "ROLLBACK: leaving '$active' serving, nginx untouched." >&2
  exit 1
fi
echo "$idle_container verified healthy and /up returns 200."

# --- atomic switch: point the nginx upstream at idle, then graceful reload.
#     nginx -t validates the rewritten file before we ever touch the live
#     process, so a bad write here fails loudly instead of reloading into a
#     broken config. ---
cat > "$UPSTREAM_CONF" <<EOF
# Generated by scripts/deploy-website.sh — do not edit by hand, it is
# overwritten on every deploy. Tracked default lives at
# upstream-website.conf.default.
upstream website_upstream {
    server website-${idle}:8080;
}
EOF

docker exec "$PROXY_CONTAINER" nginx -t
docker exec "$PROXY_CONTAINER" nginx -s reload
echo "$idle" > "$ACTIVE_COLOR_FILE"
echo "Switched: $idle is now active (nginx reloaded gracefully)."

# --- drain, then stop the old color (kept, not removed, so it's warm for
#     next time it becomes idle) ---
echo "Draining $active_service for ${DRAIN_SECONDS}s before stopping it."
sleep "$DRAIN_SECONDS"
docker compose stop "$active_service"

docker image prune -af

echo "Deploy complete. Active color: $idle. Previous color ($active) stopped, idle for next deploy."
