#!/usr/bin/env bash
# Proves every `docker exec ... artisan` in this repo runs as www.
#
# Incident 2026-10-08: the deploy ran `php artisan tunnels:reapply-config` as
# root (docker exec defaults to the container's root user). That command logs,
# so it created the day's laravel log owned by root with mode 644. The queue
# worker and php-fpm run as www and could not append to it: every log line of
# the day was lost, and 48 queued jobs failed on "could not be opened in
# append mode" on 2026-10-07.
#
# Inside the container, start.sh and supervisord already run artisan as www.
# This check covers the host side. Run from anywhere:
#   bash scripts/check-artisan-runs-as-www.sh
set -u

repo=$(cd "$(dirname "$0")/.." && pwd)
bad=0

# Shell: one line holds the whole docker exec call.
while IFS= read -r hit; do
  case "$hit" in
    *"exec -u www "*|*"exec --user www "*) ;;
    *) echo "runs as root: $hit"; bad=$((bad + 1)) ;;
  esac
done < <(grep -rnE --include='*.sh' --exclude="$(basename "$0")" 'docker (compose )?exec .*artisan' "$repo/scripts" "$repo/website" 2>/dev/null)

# Python: the call is a list or an f-string; a www user must be on the same line.
while IFS= read -r hit; do
  case "$hit" in
    *'"-u", "www"'*|*"exec -u www "*) ;;
    *) echo "runs as root: $hit"; bad=$((bad + 1)) ;;
  esac
done < <(grep -rnE --include='*.py' '"exec".*"artisan"|docker exec .*artisan' "$repo/scripts" 2>/dev/null)

if [ "$bad" -gt 0 ]; then
  echo "FAIL: $bad artisan call(s) run as root. Add -u www so the laravel log stays writable for the app."
  exit 1
fi
echo "OK: every docker exec artisan call runs as www."
