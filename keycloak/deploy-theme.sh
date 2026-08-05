#!/usr/bin/env bash
# Deploy the NoMercy Keycloak theme to this host's stack and wait until it serves.
#
# Themes are bind-mounted, so the files are already in place once they are saved
# on disk — but Keycloak compiles and caches them, and that cache is only cleared
# by a container RECREATE. `docker restart` reuses the old container and keeps the
# stale theme, which is what makes edits look like they did nothing.
#
# Keycloak serves theme resources with a long max-age and no validator, and the
# build-id segment in /resources/<id>/ does not change on a recreate. The only
# thing that frees a browser already holding an asset is a different URL, which
# is what nmAssetVersion is for. Bumping it by hand does not survive a session of
# repeated edits — ship five revisions behind one version and every browser that
# loaded the page in the middle is pinned to a half-finished stylesheet for a
# month. So it is derived from the theme's own bytes here: same files, same URL;
# any change, new URL.
set -euo pipefail

cd "$(dirname "$0")/.."

REALM="${KEYCLOAK_REALM:-NoMercyTV}"
HEALTH_URL="${KEYCLOAK_HEALTH_URL:-https://auth-dev.nomercy.tv/realms/${REALM}/account/}"
THEME_DIR="keycloak/themes/NoMercy/login"
PROPERTIES="${THEME_DIR}/theme.properties"

# Hash every file the browser can end up holding, plus the templates that
# reference them. The version line itself is excluded so the hash is stable.
fingerprint() {
	{
		find "${THEME_DIR}/resources" -type f -print0 | sort -z | xargs -0 sha1sum
		find "${THEME_DIR}" -maxdepth 1 -name '*.ftl' -print0 | sort -z | xargs -0 sha1sum
		grep -v '^nmAssetVersion=' "${PROPERTIES}"
	} | sha1sum | cut -c1-10
}

VERSION="$(fingerprint)"
CURRENT="$(sed -n 's/^nmAssetVersion=//p' "${PROPERTIES}")"

if [ "${VERSION}" != "${CURRENT}" ]; then
	echo "asset version ${CURRENT:-none} -> ${VERSION}"
	# In place, preserving the file's own line endings.
	sed -i "s/^nmAssetVersion=.*/nmAssetVersion=${VERSION}/" "${PROPERTIES}"
else
	echo "asset version ${VERSION} unchanged"
fi

echo "recreating keycloak (clears the theme cache)..."
docker compose -f docker-compose.yml -p nomercy-stack --env-file .env \
	up -d --force-recreate --no-deps keycloak

echo "waiting for ${HEALTH_URL} ..."
for attempt in $(seq 1 45); do
	code="$(curl -s -o /dev/null -w '%{http_code}' -m 5 "${HEALTH_URL}" || true)"
	if [ "${code}" = "200" ]; then
		echo "ready after ${attempt} attempt(s), assets at ?v=${VERSION}"
		exit 0
	fi
	sleep 4
done

echo "keycloak did not serve ${HEALTH_URL} in time; last status: ${code:-none}" >&2
exit 1
