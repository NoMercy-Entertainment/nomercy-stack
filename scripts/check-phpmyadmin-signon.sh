#!/bin/bash
# phpMyAdmin's Keycloak sign-on binds the code callback to the browser (stack#24), and the container
# gets only the variables it reads, never the whole stack .env (stack#23).
# Runs the real phpmyadmin/*.php under PHP's built-in server. Keycloak is a dead address, so a
# callback that passes the state check fails later at the token exchange (a redirect, not a 400).
set -u
DIR="$(cd "$(dirname "$0")/.." && pwd)"
PHP="${PHP:-php}"
PORT="${PMA_TEST_PORT:-18471}"
fail=0
check() { if [ "$2" = "$3" ]; then echo "PASS $1"; else echo "FAIL $1 (want '$3' got '$2')"; fail=1; fi; }

export KEYCLOAK_FRONTEND_URL=127.0.0.1:9 KEYCLOAK_REALM=TestRealm KEYCLOAK_CLIENT_ID=pma-test \
  KEYCLOAK_CLIENT_SECRET=not-a-secret MYSQL_SERVER_NAME=https://pma.example.test
"$PHP" -S "127.0.0.1:$PORT" "$DIR/scripts/phpmyadmin-signon-router.php" > /dev/null 2>&1 &
PID=$!
trap 'kill $PID 2>/dev/null' EXIT
for _ in $(seq 1 50); do curl -s -o /dev/null "http://127.0.0.1:$PORT/" && break; sleep 0.2; done
URL="http://127.0.0.1:$PORT/auth.php"

head=$(curl -s -D - -o /dev/null "$URL")
code=$(printf '%s' "$head" | head -n 1 | cut -d' ' -f2)
state=$(printf '%s' "$head" | grep -i '^location:' | grep -oE '[?&]state=[A-Za-z0-9]+' | cut -d= -f2)
cookie=$(printf '%s' "$head" | grep -i '^set-cookie: nm_oidc_state=' | head -n 1 | cut -d= -f2 | cut -d';' -f1)
check "login redirects to Keycloak" "$code" "302"
check "the login URL carries a long random state" "$([ ${#state} -ge 32 ] && echo yes || echo "no (${#state} chars)")" "yes"
check "the state is also kept in a cookie" "$([ -n "$state" ] && [ "$state" = "$cookie" ] && echo same || echo different)" "same"
check "the state cookie is HttpOnly and Secure" \
  "$(printf '%s' "$head" | grep -i '^set-cookie: nm_oidc_state=' | grep -ci 'httponly' | tr -d ' ')$(printf '%s' "$head" | grep -i '^set-cookie: nm_oidc_state=' | grep -ci 'secure' | tr -d ' ')" "11"

status() { curl -s -o /dev/null -w '%{http_code}' -b "nm_oidc_state=${cookie:-none}" "$URL?callback=1&code=abc$1"; }
check "a callback with a foreign state is refused" "$(status '&state=0000000000000000000000000000000000000000')" "400"
check "a callback without a state is refused" "$(status '')" "400"
check "a callback without the cookie is refused" \
  "$(curl -s -o /dev/null -w '%{http_code}' "$URL?callback=1&code=abc&state=${state:-x}")" "400"
check "a callback with the matching state reaches the token exchange" "$(status "&state=${state:-x}")" "302"

compose="$DIR/phpmyadmin/phpmyadmin-compose.yml"
check "the container does not mount the stack .env" "$(grep -cE '\.env:/' "$compose" | tr -d ' ')" "0"
for v in KEYCLOAK_FRONTEND_URL KEYCLOAK_REALM KEYCLOAK_CLIENT_ID KEYCLOAK_CLIENT_SECRET MYSQL_SERVER_NAME MYSQL_CSP_ALLOW MYSQL_USERNAME MYSQL_PASSWORD; do
  check "the container gets $v" "$(grep -cE "^\s+- $v=" "$compose" | tr -d ' ')" "1"
done

[ $fail = 0 ] && echo "phpMyAdmin sign-on checks passed" || echo "phpMyAdmin sign-on checks FAILED"
exit $fail
