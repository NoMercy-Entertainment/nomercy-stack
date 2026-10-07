#!/usr/bin/env bash
# Proves the proxy leaves API cache headers to Laravel.
#
# Incident 2026-10-07: website.conf and dev_nomercy.tv.conf added
# `Cache-Control: max-age=31536000` at server level, so every API answer
# (app_config, settings, legal text) carried two Cache-Control headers:
# Laravel's "no-cache, private" and the proxy's one-year max-age.
#
# The check runs the real site config in an nginx container, with a stub
# upstream that answers like Laravel does, and asks for one API path and one
# static asset. Needs docker. Run from anywhere:
#   bash scripts/check-proxy-cache-headers.sh
set -u
export MSYS_NO_PATHCONV=1 # Git Bash on Windows must not rewrite /v1/info into a Windows path

repo=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
# docker.exe on Windows needs a Windows path for docker cp; cygpath gives it.
command -v cygpath >/dev/null 2>&1 && work=$(cygpath -m "$work")
name="proxy-cache-check-$$"
trap 'docker rm -f "$name" >/dev/null 2>&1; rm -rf "$work"' EXIT

failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }

mkdir -p "$work/sites"
cat > "$work/nginx.conf" <<'EOF'
events {}
http {
    include /etc/nginx/sites/*.conf;
}
EOF

# The stub upstream answers every path with Laravel's own header.
cat > "$work/sites/upstream-website.conf" <<'EOF'
upstream website_upstream { server 127.0.0.1:9000; }
server {
    listen 9000;
    location / {
        add_header Cache-Control "no-cache, private";
        return 200 "ok";
    }
}
EOF

cp "$repo/proxy/sites/00-limits.conf" "$work/sites/00-limits.conf"

for site in website dev_nomercy.tv; do
  # TLS is not what is under test: drop the certificate lines and the ssl flag.
  sed -E -e '/ssl_certificate/d' -e 's/ ssl;/;/' \
    "$repo/proxy/sites/$site.conf" > "$work/sites/$site.conf"
done
# Both sites listen on 443 in the real stack; the check gives each its own port.
sed -i -E 's/listen 443;/listen 8443;/; s/listen \[::\]:443;/listen [::]:8443;/' "$work/sites/website.conf"
sed -i -E 's/listen 443;/listen 8444;/; s/listen \[::\]:443;/listen [::]:8444;/' "$work/sites/dev_nomercy.tv.conf"

docker create --add-host keycloak:127.0.0.1 --name "$name" nginx:1.29.5 >/dev/null || { echo "FAIL: docker create"; exit 1; }
docker cp "$work/nginx.conf" "$name:/etc/nginx/nginx.conf"
docker cp "$work/sites" "$name:/etc/nginx/sites"
docker start "$name" >/dev/null || { echo "FAIL: docker start"; exit 1; }
sleep 2
docker exec "$name" nginx -t >/dev/null 2>&1 || { docker logs "$name" 2>&1 | tail -5; echo "FAIL: nginx -t"; exit 1; }

probe() { # port host path -> the Cache-Control header lines
  docker exec "$name" curl -s -D - -o /dev/null -H "Host: $2" "http://127.0.0.1:$1$3" \
    | tr -d '\r' | grep -i '^cache-control' || true
}

check() { # label port host
  local api static
  api=$(probe "$2" "$3" /v1/info)
  static=$(probe "$2" "$3" /build/app.js)
  echo "$1 /v1/info      -> $(echo "$api" | tr '\n' '|')"
  echo "$1 /build/app.js -> $(echo "$static" | tr '\n' '|')"
  [ "$(echo "$api" | wc -l)" -eq 1 ] || fail "$1: API answer has more than one Cache-Control header"
  echo "$api" | grep -qi 'max-age=31536000' && fail "$1: API answer carries the one-year max-age"
  echo "$api" | grep -qi 'no-cache, private' || fail "$1: API answer lost Laravel's own header"
}

check "website" 8443 api.nomercy.tv
check "dev" 8444 api-dev.nomercy.tv

if [ "$failures" -gt 0 ]; then
  echo "RESULT: FAIL ($failures)"
  exit 1
fi
echo "RESULT: PASS"
