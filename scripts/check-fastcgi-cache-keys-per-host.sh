#!/usr/bin/env bash
# Proves every FastCGI cache key in the website config includes the host.
#
# Incident 2026-10-09: api.nomercy.tv, cdn.nomercy.tv and nomercy.tv are one
# server block and one Laravel app. The anonymous homepage location used the
# fixed key "home:anonymous", so the first host to ask for / filled the cache
# for all three. api.nomercy.tv/ answered with the website homepage, and
# nomercy.tv/ could answer with the api's {"status":"ok"}.
#
# A key without $host shares one answer between hosts. Run from anywhere:
#   bash scripts/check-fastcgi-cache-keys-per-host.sh
set -u

repo=$(cd "$(dirname "$0")/.." && pwd)
failures=0
checked=0

while IFS=: read -r file line text; do
    checked=$((checked + 1))
    case "$text" in
        *'$host'*) ;;
        *) echo "FAIL: $file:$line has a cache key without \$host: $text"; failures=$((failures + 1)) ;;
    esac
done < <(grep -rn --include='*.conf' 'fastcgi_cache_key' "$repo/website/config")

if [ "$checked" -eq 0 ]; then
    echo "FAIL: found no fastcgi_cache_key under website/config"
    exit 1
fi

echo "checked=$checked failures=$failures"
[ "$failures" -eq 0 ]
