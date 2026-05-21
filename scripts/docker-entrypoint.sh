#!/bin/sh
set -e

# Capture runtime UID/GID from environment variables, defaulting to 1000
PUID=${USER_UID:-1000}
PGID=${USER_GID:-1000}

# Adjust the node user's UID/GID if they differ from the runtime request
# and fix volume ownership only when a remap is needed
changed=0

if [ "$(id -u node)" -ne "$PUID" ]; then
    echo "Updating node UID to $PUID"
    usermod -o -u "$PUID" node
    changed=1
fi

if [ "$(id -g node)" -ne "$PGID" ]; then
    echo "Updating node GID to $PGID"
    groupmod -o -g "$PGID" node
    usermod -g "$PGID" node
    changed=1
fi

if [ "$changed" = "1" ]; then
    chown -R node:node /paperclip
fi

# Always ensure /paperclip is writable. On Railway, the Volume is mounted as root
# over the build-time directory, so the chown from the Dockerfile does not persist.
mkdir -p /paperclip/instances/default/logs
chown -R node:node /paperclip 2>/dev/null || true
chmod -R u+rwX,g+rwX,o+rX /paperclip 2>/dev/null || true

# If RUN_AS_ROOT=1 or the mounted volume blocks chown (Railway), run as root.
if [ "${RUN_AS_ROOT:-0}" = "1" ] || ! su -s /bin/sh node -c 'test -w /paperclip/instances/default/logs' 2>/dev/null; then
    echo "INFO: running entrypoint as root (volume not writable by node user)"
    exec "$@"
fi

exec gosu node "$@"
