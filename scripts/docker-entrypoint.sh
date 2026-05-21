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

# Always ensure /paperclip is writable by the node user. On Railway, the Volume is
# mounted as root over the build-time directory, so the chown from the Dockerfile
# does not persist. This is cheap when ownership is already correct.
chown -R node:node /paperclip 2>/dev/null || true
mkdir -p /paperclip/instances/default/logs 2>/dev/null || true
chown -R node:node /paperclip/instances 2>/dev/null || true

# On platforms (e.g. Railway) where chown on the mounted volume is not permitted,
# fall back to running as root rather than failing with EACCES on first write.
if ! su -s /bin/sh node -c 'test -w /paperclip' 2>/dev/null; then
    echo "WARN: /paperclip not writable by node user, falling back to root"
    exec "$@"
fi

exec gosu node "$@"
