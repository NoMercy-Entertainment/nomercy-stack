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
LOGIN_DIR="keycloak/themes/NoMercy/login"
ACCOUNT_DIR="keycloak/themes/NoMercy/account"

# Hash every file the browser can end up holding, plus the templates that
# reference them. Any existing version string is stripped first so the hash
# depends on the theme's content and not on its own previous value.
#
# CR is stripped before hashing: a checkout on Windows and one on the Linux box
# hold the same files with different line endings, and hashing the raw bytes gave
# the same theme two different versions depending on where the script ran. That
# still busts caches, but it means the version is not an identity for the theme's
# content, so the two hosts can never be compared by it.
fingerprint() {
	local dir="$1"
	{
		find "${dir}/resources" "${dir}" -maxdepth 1 -type f -name '*.ftl' -print0 2>/dev/null
		find "${dir}/resources" -type f -print0
	} | LC_ALL=C sort -zu | while IFS= read -r -d '' file; do
		printf '%s %s\n' "${file}" "$(tr -d '\r' < "${file}" | sha1sum | cut -d' ' -f1)"
	done | {
		cat
		sed -E 's/\?v=[0-9a-f]+//g; /^nmAssetVersion=/d' "${dir}/theme.properties" | tr -d '\r'
	} | sha1sum | cut -d' ' -f1 | cut -c1-10
}

# The login theme carries its version in one property the templates interpolate;
# the account theme, having no templates of ours, pins ?v= on each asset in
# theme.properties. Both are rewritten from the same fingerprint.
stamp_login() {
	local version="$1" file="${LOGIN_DIR}/theme.properties"
	local current
	current="$(sed -n 's/^nmAssetVersion=//p' "${file}")"
	[ "${version}" = "${current}" ] && { echo "login assets ${version} unchanged"; return; }
	echo "login assets ${current:-none} -> ${version}"
	sed -i "s/^nmAssetVersion=.*/nmAssetVersion=${version}/" "${file}"
}

stamp_account() {
	local version="$1" file="${ACCOUNT_DIR}/theme.properties"
	grep -q "?v=${version}" "${file}" && { echo "account assets ${version} unchanged"; return; }
	echo "account assets -> ${version}"
	sed -i -E "s/\?v=[0-9a-f]+/?v=${version}/g" "${file}"
}

LOGIN_VERSION="$(fingerprint "${LOGIN_DIR}")"
ACCOUNT_VERSION="$(fingerprint "${ACCOUNT_DIR}")"
stamp_login "${LOGIN_VERSION}"
stamp_account "${ACCOUNT_VERSION}"

echo "recreating keycloak (clears the theme cache)..."
docker compose -f docker-compose.yml -p nomercy-stack --env-file .env \
	up -d --force-recreate --no-deps keycloak

echo "waiting for ${HEALTH_URL} ..."
for attempt in $(seq 1 45); do
	code="$(curl -s -o /dev/null -w '%{http_code}' -m 5 "${HEALTH_URL}" || true)"
	if [ "${code}" = "200" ]; then
		echo "ready after ${attempt} attempt(s); login ?v=${LOGIN_VERSION}, account ?v=${ACCOUNT_VERSION}"
		exit 0
	fi
	sleep 4
done

echo "keycloak did not serve ${HEALTH_URL} in time; last status: ${code:-none}" >&2
exit 1
