#!/bin/bash
# CT 302 - media-dl (qBittorrent, SABnzbd)
# Run as root on the Proxmox host after creating CT 302.
# Usage: Fill in scripts/.env, then: ./ct302-media-dl.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/common.sh"
load_env

VMID=302
STACKS_DIR=$DATA_ROOT/config/media-dl/komodo/stacks

echo "=== CT $VMID - media-dl ==="

[ -d $DATA_ROOT ] || { echo "ERROR: $DATA_ROOT not mounted. Run host-prep.sh first." >&2; exit 1; }
ct_exists $VMID || { echo "ERROR: CT $VMID not found. Create it first." >&2; exit 1; }

echo ""
echo "=== Users & groups ==="
add_group 1300 media
add_user  1307 1300 sabnzbd
add_user  1320 1300 qbittorrent

echo ""
echo "=== Data directory ownership ==="
chown 100000:1300 $DATA_ROOT/config/media-dl             && chmod 750 $DATA_ROOT/config/media-dl
chown 1307:1300   $DATA_ROOT/config/media-dl/sabnzbd     && chmod 750 $DATA_ROOT/config/media-dl/sabnzbd
chown 1320:1300   $DATA_ROOT/config/media-dl/qbittorrent && chmod 750 $DATA_ROOT/config/media-dl/qbittorrent

# Shared media dirs - idempotent, also set by ct300 and ct301
chown root:1300 \
    $DATA_ROOT/media-stack/torrents \
    $DATA_ROOT/media-stack/torrents/tv \
    $DATA_ROOT/media-stack/torrents/movies \
    $DATA_ROOT/media-stack/usenet \
    $DATA_ROOT/media-stack/usenet/complete \
    $DATA_ROOT/media-stack/usenet/complete/tv \
    $DATA_ROOT/media-stack/usenet/complete/movies \
    $DATA_ROOT/media-stack/usenet/incomplete
chmod 775 \
    $DATA_ROOT/media-stack/torrents \
    $DATA_ROOT/media-stack/torrents/tv \
    $DATA_ROOT/media-stack/torrents/movies \
    $DATA_ROOT/media-stack/usenet \
    $DATA_ROOT/media-stack/usenet/complete \
    $DATA_ROOT/media-stack/usenet/complete/tv \
    $DATA_ROOT/media-stack/usenet/complete/movies \
    $DATA_ROOT/media-stack/usenet/incomplete
echo "  done"

echo ""
echo "=== LXC conf patches ==="
set_mp $VMID -mp0 $DATA_ROOT/config/media-dl,mp=/data
set_mp $VMID -mp1 $DATA_ROOT/media-stack/torrents,mp=/torrents
set_mp $VMID -mp2 $DATA_ROOT/media-stack/usenet,mp=/usenet

patch_conf $VMID "lxc.idmap" "lxc.idmap: u 0 100000 1000
lxc.idmap: u 1000 1000 500
lxc.idmap: u 1500 101500 64036
lxc.idmap: g 0 100000 1000
lxc.idmap: g 1000 1000 500
lxc.idmap: g 1500 101500 64036"

echo ""
echo "=== Stack files ==="
deploy_stack "$STACKS_DIR/media-dl"              "media-dl"
deploy_stack "$STACKS_DIR/node-exporter-media-dl" "node-exporter"

start_and_install_periphery $VMID /data/komodo
configure_docker_daemon $VMID

echo ""
echo "=== CT $VMID done ==="
