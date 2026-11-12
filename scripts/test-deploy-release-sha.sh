#!/bin/bash
# The website deploy must reset the idle checkout to the commit the deploy job
# tested (RELEASE_SHA), never to the tip of origin/master (stack#29).

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail=0

check() {
  if [ "$2" = "$3" ]; then
    echo "ok: $1"
  else
    echo "FAIL: $1 (expected '$2', got '$3')" >&2
    fail=1
  fi
}

if grep -n 'reset --hard origin/master' "$ROOT/scripts/deploy-website.sh"; then
  echo "FAIL: deploy-website.sh still resets to origin/master" >&2
  fail=1
fi

# shellcheck source=release-sha.sh
if ! source "$ROOT/scripts/release-sha.sh"; then
  echo "FAIL: scripts/release-sha.sh cannot be sourced" >&2
  exit 1
fi

git init -q --initial-branch=master "$TMP/origin"
git -C "$TMP/origin" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m A
sha_a=$(git -C "$TMP/origin" rev-parse HEAD)
git -C "$TMP/origin" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m B
sha_b=$(git -C "$TMP/origin" rev-parse HEAD)
git clone -q "$TMP/origin" "$TMP/idle"

RELEASE_SHA="$sha_a" reset_to_release_sha "$TMP/idle" > /dev/null
check "checkout is the release commit A, not the tip B" "$sha_a" "$(git -C "$TMP/idle" rev-parse HEAD)"

RELEASE_SHA="$sha_b" reset_to_release_sha "$TMP/idle" > /dev/null
check "checkout moves to B when RELEASE_SHA is B" "$sha_b" "$(git -C "$TMP/idle" rev-parse HEAD)"

(unset RELEASE_SHA; reset_to_release_sha "$TMP/idle" > /dev/null 2>&1)
check "exit is non-zero when RELEASE_SHA is unset" "1" "$?"

(RELEASE_SHA=0000000000000000000000000000000000000000 reset_to_release_sha "$TMP/idle" > /dev/null 2>&1)
check "exit is non-zero when RELEASE_SHA is not a commit" "1" "$?"

check "failed runs leave the checkout alone" "$sha_b" "$(git -C "$TMP/idle" rev-parse HEAD)"

exit "$fail"
