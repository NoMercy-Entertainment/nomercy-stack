#!/usr/bin/env bash
# Validates every compose file in the repo the way it is really used, without
# starting, pulling or building anything.
#
#   docker-compose.yml   the stack: its `include:` list pulls in the fragments
#                        under docker/, keycloak/, mysql/, ... so one render of
#                        the top-level file validates all of them together.
#   dns/dns-compose.yml  standalone (own .env.example), rendered alone.
#
# Two checks per entry point:
#   1. `docker compose config -q` with every profile on: YAML, interpolation,
#      include paths, schema.
#   2. every `build:` context and Dockerfile the rendered config names exists.
#      `config` does not check that (issue #9: github-runner built from a
#      folder the repo never held, and `config` was happy), so this does.
#
# A `.env` is copied from `.env.example` next to each entry point when none
# exists, so the check needs no secrets. Run it from anywhere:
#   bash scripts/validate-compose.sh
set -u

repo=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo"

entry_points=(
  "docker-compose.yml"
  "dns/dns-compose.yml"
)

failures=0

# Every tracked compose file must be covered: either an entry point above, or
# included by the top-level file. A new fragment nobody wired in is a failure.
while IFS= read -r file; do
  covered=0
  for ep in "${entry_points[@]}"; do
    [ "$file" = "$ep" ] && covered=1
  done
  if [ "$covered" = 0 ] && ! grep -Eq "^\s*-\s*\./$file\s*$" docker-compose.yml; then
    echo "FAIL $file: not an entry point and not included by docker-compose.yml"
    failures=$((failures + 1))
  fi
done < <(git ls-files '*compose*.yml' '*compose*.yaml' ':!.github/**')

for ep in "${entry_points[@]}"; do
  dir=$(dirname "$ep")
  file=$(basename "$ep")
  if [ -f "$dir/.env.example" ] && [ ! -f "$dir/.env" ]; then
    cp "$dir/.env.example" "$dir/.env"
    echo "info $ep: .env copied from .env.example"
  fi

  if ! (cd "$dir" && docker compose -f "$file" --profile '*' config -q); then
    echo "FAIL $ep: docker compose config"
    failures=$((failures + 1))
    continue
  fi

  # every build context folder and Dockerfile the rendered config names exists
  build_errors=$(cd "$dir" && docker compose -f "$file" --profile '*' config --format json 2>/dev/null \
    | python3 -c '
import json, os, sys
cfg = json.load(sys.stdin)
for name, svc in sorted(cfg.get("services", {}).items()):
    b = svc.get("build")
    if isinstance(b, str):
        b = {"context": b}
    if not b:
        continue
    ctx = b.get("context", ".")
    df = os.path.join(ctx, b.get("dockerfile", "Dockerfile"))
    if not os.path.isdir(ctx):
        print("service %s builds from %s, a folder that does not exist" % (name, ctx))
    elif not os.path.isfile(df):
        print("service %s builds with %s, a file that does not exist" % (name, df))
')
  if [ -n "$build_errors" ]; then
    while IFS= read -r line; do
      echo "FAIL $ep: $line"
      failures=$((failures + 1))
    done <<< "$build_errors"
    continue
  fi

  echo "ok   $ep"
done

if [ "$failures" -gt 0 ]; then
  echo "$failures failure(s)"
  exit 1
fi
echo "all compose files valid"
