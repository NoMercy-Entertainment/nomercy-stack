#!/bin/bash
# infra/nomercy-stack/keycloak/build-provider.sh
#
# Builds the passwordless authenticator from providers-src/ into providers/,
# the folder Keycloak loads at start. The jar is a build output and is not in
# git, so every host builds its own from the committed source: the jar then
# always matches the pom's keycloak.version, and no host needs a JDK. Dev and
# prod once ran different jars (one built for 26.6.4, one for 26.7.2) because
# each was built by hand.
#
# Run after a pull that changes providers-src/ or keycloak.version, then
# recreate the keycloak container. Needs only Docker.
#   ./keycloak/build-provider.sh

set -euo pipefail

KEYCLOAK_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$KEYCLOAK_DIR/providers-src/nomercy-passwordless"
JAR="nomercy-passwordless-authenticator.jar"

docker run --rm \
    -v "$SRC:/src" \
    -v nomercy-maven-cache:/root/.m2 \
    -w /src \
    maven:3.9-eclipse-temurin-21 \
    mvn -q -B package -DskipTests

cp "$SRC/target/$JAR" "$KEYCLOAK_DIR/providers/$JAR"
unzip -p "$KEYCLOAK_DIR/providers/$JAR" \
    META-INF/maven/tv.nomercy.keycloak/nomercy-passwordless-authenticator/pom.properties \
    2>/dev/null | grep '^version=' || true
