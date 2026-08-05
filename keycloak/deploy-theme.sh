#!/usr/bin/env bash
# Deploy the NoMercy Keycloak theme to this host's stack and wait until it serves.
#
# Themes are bind-mounted, so the files are already in place once they are saved
# on disk — but Keycloak compiles and caches them, and that cache is only cleared
# by a container RECREATE. `docker restart` reuses the old container and keeps the
# stale theme, which is what makes edits look like they did nothing.
set -euo pipefail

cd "$(dirname "$0")/.."

REALM="${KEYCLOAK_REALM:-NoMercyTV}"
HEALTH_URL="${KEYCLOAK_HEALTH_URL:-https://auth-dev.nomercy.tv/realms/${REALM}/account/}"

echo "recreating keycloak (clears the theme cache)..."
docker compose -f docker-compose.yml -p nomercy-stack --env-file .env \
	up -d --force-recreate --no-deps keycloak

echo "waiting for ${HEALTH_URL} ..."
for attempt in $(seq 1 45); do
	code="$(curl -s -o /dev/null -w '%{http_code}' -m 5 "${HEALTH_URL}" || true)"
	if [ "${code}" = "200" ]; then
		echo "ready after ${attempt} attempt(s)"
		exit 0
	fi
	sleep 4
done

echo "keycloak did not serve ${HEALTH_URL} in time; last status: ${code:-none}" >&2
exit 1
