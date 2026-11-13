#!/bin/bash
# Gives the host a rootless Docker daemon under the unprivileged user
# plugin-builder, for marketplace plugin builds. Idempotent. Run as root:
#   /opt/nomercy-stack/scripts/provision-plugin-builder.sh

set -euo pipefail

BUILDER="plugin-builder"
BUILDER_HOME="/var/lib/plugin-builder"
WEB_UID=1000
WEB_GID=1000
SOCKET_DIR="/run/plugin-builder"
SOCKET="$SOCKET_DIR/docker.sock"
BUILD_TMP="/srv/plugin-build/tmp"

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: must run as root" >&2
    exit 1
fi

write_if_changed() {
    local dest="$1" mode="$2" content
    content="$(cat)"
    if [ -f "$dest" ] && [ "$(cat "$dest")" = "$content" ]; then
        return 1
    fi
    install -d -m 0755 "$(dirname "$dest")"
    printf '%s\n' "$content" > "$dest"
    chmod "$mode" "$dest"
    echo "Wrote $dest"
}

missing=()
for pkg in uidmap slirp4netns acl dbus-user-session; do
    dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
done
if [ "${#missing[@]}" -gt 0 ]; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}"
fi

if ! id "$BUILDER" >/dev/null 2>&1; then
    useradd --system --user-group --create-home --home-dir "$BUILDER_HOME" \
        --shell /usr/sbin/nologin "$BUILDER"
    echo "Created user $BUILDER"
fi
BUILDER_UID="$(id -u "$BUILDER")"
RUNTIME_DIR="/run/user/$BUILDER_UID"

# A system user gets no subordinate ids; take the first range no other user holds.
if ! grep "^$BUILDER:" /etc/subuid > /dev/null || ! grep "^$BUILDER:" /etc/subgid > /dev/null; then
    start="$(cat /etc/subuid /etc/subgid | awk -F: 'BEGIN { m = 100000 } { e = $2 + $3; if (e > m) m = e } END { print m }')"
    end=$((start + 65535))
    grep "^$BUILDER:" /etc/subuid > /dev/null || usermod --add-subuids "$start-$end" "$BUILDER"
    grep "^$BUILDER:" /etc/subgid > /dev/null || usermod --add-subgids "$start-$end" "$BUILDER"
    echo "Subordinate ids $start-$end given to $BUILDER"
fi

# Ubuntu 24.04 refuses an unprivileged user namespace unless a profile allows the binary.
restrict=/proc/sys/kernel/apparmor_restrict_unprivileged_userns
if [ -f "$restrict" ] && [ "$(cat "$restrict")" = "1" ] && ! grep -rl "rootlesskit" /etc/apparmor.d > /dev/null 2>&1; then
    write_if_changed /etc/apparmor.d/usr.bin.rootlesskit 0644 <<'EOF' || true
abi <abi/4.0>,
include <tunables/global>

/usr/bin/rootlesskit flags=(unconfined) {
  userns,
  include if exists <local/usr.bin.rootlesskit>
}
EOF
    systemctl restart apparmor.service
fi

# Without cpu delegation a rootless daemon drops the build's --cpus limit.
delegate_changed=0
write_if_changed /etc/systemd/system/user@.service.d/delegate.conf 0644 <<'EOF' && delegate_changed=1
[Service]
Delegate=cpu cpuset io memory pids
EOF
if [ "$delegate_changed" = 1 ]; then
    systemctl daemon-reload
    if systemctl is-active --quiet "user@$BUILDER_UID.service"; then
        systemctl restart "user@$BUILDER_UID.service"
    fi
fi

# /run is a tmpfs: tmpfiles.d puts the socket folder and its ACL back on every boot.
# The default ACL gives each new socket to the website uid; nobody else gets in.
write_if_changed /etc/tmpfiles.d/plugin-builder.conf 0644 <<EOF || true
d $SOCKET_DIR 0750 $BUILDER $BUILDER -
a+ $SOCKET_DIR - - - - u:$WEB_UID:r-x,d:u::rwx,d:g::r-x,d:o::---,d:u:$WEB_UID:rw-
EOF
systemd-tmpfiles --create /etc/tmpfiles.d/plugin-builder.conf

# Build work folder: the website writes it, the build container (root in the
# user namespace = $BUILDER on the host) reads src and writes out.
install -d -m 0755 "$(dirname "$BUILD_TMP")"
install -d -m 0770 -o "$WEB_UID" -g "$WEB_GID" "$BUILD_TMP"
setfacl -m "u:$BUILDER:rwx,d:u:$BUILDER:rwx,d:u:$WEB_UID:rwx" "$BUILD_TMP"

loginctl enable-linger "$BUILDER"
for _ in $(seq 1 30); do
    [ -S "$RUNTIME_DIR/bus" ] && break
    sleep 1
done
[ -S "$RUNTIME_DIR/bus" ] || { echo "ERROR: no systemd user session for $BUILDER at $RUNTIME_DIR/bus" >&2; exit 1; }

as_builder() {
    (cd / && runuser -u "$BUILDER" -- env HOME="$BUILDER_HOME" XDG_RUNTIME_DIR="$RUNTIME_DIR" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=$RUNTIME_DIR/bus" "$@")
}

# The setup tool checks the daemon on its default socket, so it runs before daemon.json moves it.
if [ ! -f "$BUILDER_HOME/.config/systemd/user/docker.service" ]; then
    as_builder dockerd-rootless-setuptool.sh install
fi

daemon_json="$BUILDER_HOME/.config/docker/daemon.json"
wanted="{ \"hosts\": [\"unix://$SOCKET\"] }"
if [ ! -f "$daemon_json" ] || [ "$(cat "$daemon_json")" != "$wanted" ]; then
    as_builder mkdir -p "$(dirname "$daemon_json")"
    printf '%s\n' "$wanted" | as_builder tee "$daemon_json" > /dev/null
    echo "Wrote $daemon_json"
    as_builder systemctl --user restart docker.service
fi
as_builder systemctl --user enable docker.service > /dev/null
as_builder systemctl --user is-active --quiet docker.service || as_builder systemctl --user start docker.service

echo "Waiting for the rootless daemon on $SOCKET..."
for _ in $(seq 1 30); do
    as_builder docker -H "unix://$SOCKET" info > /dev/null 2>&1 && break
    sleep 1
done

security="$(as_builder docker -H "unix://$SOCKET" info --format '{{.SecurityOptions}}')"
echo "$security"
case "$security" in
    *rootless*) ;;
    *) echo "ERROR: the daemon on $SOCKET is not rootless" >&2; exit 1 ;;
esac

if ! setpriv --reuid "$WEB_UID" --regid "$WEB_GID" --clear-groups test -w "$SOCKET"; then
    echo "ERROR: uid $WEB_UID cannot use $SOCKET" >&2
    exit 1
fi
if [ -n "$(find "$SOCKET_DIR" -maxdepth 1 -perm /o+rwx)" ]; then
    echo "ERROR: $SOCKET_DIR or its socket is open to every user" >&2
    exit 1
fi

echo "OK: rootless plugin-builder daemon on $SOCKET, usable by $BUILDER and uid $WEB_UID only"
