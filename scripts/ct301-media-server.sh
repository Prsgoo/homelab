#!/bin/bash
# CT 301 - media-server (Jellyfin, Jellystat)
# Run as root on the Proxmox host after creating CT 301.
# Usage: Fill in scripts/.env, then: ./ct301-media-server.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/common.sh"
load_env

VMID=301
STACKS_DIR=$DATA_ROOT/config/media-server/komodo/stacks

echo "=== CT $VMID - media-server ==="

[ -d $DATA_ROOT ] || { echo "ERROR: $DATA_ROOT not mounted. Run host-prep.sh first." >&2; exit 1; }
ct_exists $VMID || { echo "ERROR: CT $VMID not found. Create it first." >&2; exit 1; }

echo ""
echo "=== Users & groups ==="
add_group 1300 media
add_user  1310 1300 jellyfin

echo ""
echo "=== Data directory ownership ==="
chown 100000:1300 $DATA_ROOT/config/media-server          && chmod 750 $DATA_ROOT/config/media-server
chown 1310:1300   $DATA_ROOT/config/media-server/jellyfin && chmod 750 $DATA_ROOT/config/media-server/jellyfin

# Shared media dirs - idempotent, also set by ct300 and ct302
chown root:1300 \
    $DATA_ROOT/media-stack/media/tv \
    $DATA_ROOT/media-stack/media/anime \
    $DATA_ROOT/media-stack/media/movies \
    $DATA_ROOT/media-stack/media/movies-4k
chmod 775 \
    $DATA_ROOT/media-stack/media/tv \
    $DATA_ROOT/media-stack/media/anime \
    $DATA_ROOT/media-stack/media/movies \
    $DATA_ROOT/media-stack/media/movies-4k
echo "  done"

echo ""
echo "=== LXC conf patches ==="
set_mp $VMID -mp0 $DATA_ROOT/config/media-server,mp=/data
set_mp $VMID -mp1 "$DATA_ROOT/media-stack/media,mp=/media,ro=1"

patch_conf $VMID "lxc.idmap" "lxc.idmap: u 0 100000 1000
lxc.idmap: u 1000 1000 500
lxc.idmap: u 1500 101500 64036
lxc.idmap: g 0 100000 1000
lxc.idmap: g 1000 1000 500
lxc.idmap: g 1500 101500 64036"

echo ""
echo "=== Stack files ==="
deploy_stack "$STACKS_DIR/media-server" "media-server" \
    POSTGRES_PASSWORD JWT_SECRET
deploy_stack "$STACKS_DIR/node-exporter-media-server" "node-exporter"

start_and_install_periphery $VMID /data/komodo
configure_docker_daemon $VMID

echo ""
echo "=== CT $VMID done ==="
