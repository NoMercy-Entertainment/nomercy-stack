#!/bin/bash
# Sourced by deploy-website.sh. Resets a checkout to the commit the deploy job tested.

reset_to_release_sha() {
  local dir="$1"
  if [ -z "${RELEASE_SHA:-}" ]; then
    echo "ERROR: RELEASE_SHA is not set; the deploy needs the commit the deploy job tested." >&2
    return 1
  fi
  git -C "$dir" fetch origin master || return 1
  if ! git -C "$dir" rev-parse --verify --quiet "${RELEASE_SHA}^{commit}" > /dev/null; then
    echo "ERROR: RELEASE_SHA '$RELEASE_SHA' is not a commit in $dir after fetching origin master." >&2
    return 1
  fi
  git -C "$dir" reset --hard "$RELEASE_SHA"
}
