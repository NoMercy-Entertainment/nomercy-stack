#!/usr/bin/env bash
# Proves a website container can reach only the rootless plugin-builder Docker
# daemon: no root socket, no folder that holds it, no other DOCKER_HOST.
#   bash scripts/check-plugin-builder.sh [compose-file]
set -u

repo=$(cd "$(dirname "$0")/.." && pwd)
file="${1:-$repo/website/website-compose.yml}"
socket="/run/plugin-builder/docker.sock"
bad=0

if [ ! -f "$file" ]; then
  echo "FAIL: $file not found"
  exit 1
fi

fail() {
  echo "FAIL $(basename "$file"):$1: $2"
  bad=$((bad + 1))
}

n=0
while IFS= read -r line || [ -n "$line" ]; do
  n=$((n + 1))
  text="${line%$'\r'}"
  text="${text#"${text%%[![:space:]]*}"}"
  case "$text" in
    \#*) continue ;;
  esac

  # Any docker.sock other than the builder's, in any syntax (short, long, env, command).
  rest="${text//$socket/}"
  case "$rest" in
    *docker.sock*) fail "$n" "a Docker socket other than $socket: $text" ;;
  esac

  # A bind source that holds the root socket: /, /run, /var or /var/run.
  source=""
  case "$text" in
    *source:*) source="${text#*source:}"; source="${source%%[,\}]*}" ;;
    -\ *) source="${text#- }"; source="${source%%:*}" ;;
  esac
  source="${source//[\"\' ]/}"
  while [ "${#source}" -gt 1 ] && [ "${source%/}" != "$source" ]; do source="${source%/}"; done
  case "$source" in
    /|/run|/var|/var/run) fail "$n" "bind source $source holds the root Docker socket" ;;
  esac
done < <(cat "$file")

if ! grep -F "DOCKER_HOST=unix://$socket" "$file" > /dev/null; then
  fail 0 "no DOCKER_HOST=unix://$socket; the docker client would fall back to /var/run/docker.sock"
fi

if [ "$bad" -gt 0 ]; then
  echo "FAIL: $bad finding(s). A website container gets only $socket."
  exit 1
fi
echo "OK: $(basename "$file") gives the website containers only $socket."
