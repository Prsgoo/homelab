#!/bin/bash
# CT 304 - games (RomM)
# Run as root on the Proxmox host after creating CT 304.
# Usage: Fill in scripts/.env, then: ./ct304-games.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/common.sh"
load_env

VMID=304
STACKS_DIR=$DATA_ROOT/config/media-games/komodo/stacks

echo "=== CT $VMID - games ==="

[ -d $DATA_ROOT ] || { echo "ERROR: $DATA_ROOT not mounted. Run host-prep.sh first." >&2; exit 1; }
ct_exists $VMID || { echo "ERROR: CT $VMID not found. Create it first." >&2; exit 1; }

echo ""
echo "=== Users & groups ==="
add_group 1300 media
add_user  1340 1300 romm

echo ""
echo "=== Data directory ownership ==="
chown 100000:1300   $DATA_ROOT/config/media-games              && chmod 750 $DATA_ROOT/config/media-games
# RomM UID behaviour: verify after first container start (see service-uid-exceptions.md if needed)
chown 100000:1300   $DATA_ROOT/config/media-games/romm         && chmod 750 $DATA_ROOT/config/media-games/romm
chown 100000:1300   $DATA_ROOT/config/media-games/romm/assets  && chmod 750 $DATA_ROOT/config/media-games/romm/assets
chown 100000:1300   $DATA_ROOT/config/media-games/romm/config  && chmod 750 $DATA_ROOT/config/media-games/romm/config
chown 100000:1300   $DATA_ROOT/config/media-games/romm/redis   && chmod 750 $DATA_ROOT/config/media-games/romm/redis
# MariaDB runs as UID 999 inside container -> maps to host UID 100999
chown 100999:100999 $DATA_ROOT/config/media-games/mariadb      && chmod 750 $DATA_ROOT/config/media-games/mariadb

# ROMs dir on media pool - root:media 775 so all media CTs can read
chown root:1300 $DATA_ROOT/media-stack/games/roms
chmod 775       $DATA_ROOT/media-stack/games/roms

# FileBrowser (CT 100) runs as container root = host UID 100000 - needs ACL access
setfacl -Rm u:100000:rwx,d:u:100000:rwx $DATA_ROOT/config/media-games
echo "  done"

echo ""
echo "=== LXC conf patches ==="
set_mp $VMID -mp0 $DATA_ROOT/config/media-games,mp=/data
set_mp $VMID -mp1 $DATA_ROOT/media-stack/games/roms,mp=/roms

patch_conf $VMID "lxc.idmap" "lxc.idmap: u 0 100000 1000
lxc.idmap: u 1000 1000 500
lxc.idmap: u 1500 101500 64036
lxc.idmap: g 0 100000 1000
lxc.idmap: g 1000 1000 500
lxc.idmap: g 1500 101500 64036"

echo ""
echo "=== Stack files ==="
deploy_stack "$STACKS_DIR/media-games"               "media-games" ROMM_DB_PASSWORD ROMM_DB_ROOT_PASSWORD ROMM_AUTH_SECRET_KEY IGDB_CLIENT_ID IGDB_CLIENT_SECRET
deploy_stack "$STACKS_DIR/node-exporter-games" "node-exporter"

start_and_install_periphery $VMID /data/komodo
configure_docker_daemon $VMID

echo ""
echo "=== CT $VMID done ==="
echo "    Next: deploy the games stack in Komodo."
echo "    Then: open RomM and create an admin account."
