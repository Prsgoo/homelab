#!/bin/bash
# CT 300 - media-arr (Sonarr, Radarr, Prowlarr, Bazarr, Seerr, Dispatcharr)
# Run as root on the Proxmox host after creating CT 300.
# Usage: Fill in scripts/.env, then: ./ct300-media-arr.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/common.sh"
load_env

VMID=300
STACKS_DIR=$DATA_ROOT/config/media-arr/komodo/stacks

echo "=== CT $VMID - media-arr ==="

[ -d $DATA_ROOT ] || { echo "ERROR: $DATA_ROOT not mounted. Run host-prep.sh first." >&2; exit 1; }
ct_exists $VMID || { echo "ERROR: CT $VMID not found. Create it first." >&2; exit 1; }

echo ""
echo "=== Users & groups ==="
add_group 1300 media
add_user  1300 1300 sonarr
add_user  1301 1300 radarr
add_user  1302 1300 prowlarr
add_user  1303 1300 bazarr
add_user  1305 1300 unpackerr
add_user  1306 1300 recyclarr

echo ""
echo "=== Data directory ownership ==="
chown 100000:1300 $DATA_ROOT/config/media-arr            && chmod 750 $DATA_ROOT/config/media-arr
chown 1300:1300   $DATA_ROOT/config/media-arr/sonarr     && chmod 750 $DATA_ROOT/config/media-arr/sonarr
chown 1301:1300   $DATA_ROOT/config/media-arr/radarr     && chmod 750 $DATA_ROOT/config/media-arr/radarr
chown 1302:1300   $DATA_ROOT/config/media-arr/prowlarr   && chmod 750 $DATA_ROOT/config/media-arr/prowlarr
chown 1303:1300   $DATA_ROOT/config/media-arr/bazarr     && chmod 750 $DATA_ROOT/config/media-arr/bazarr
chown 1000:1000   $DATA_ROOT/config/media-arr/seerr      && chmod 750 $DATA_ROOT/config/media-arr/seerr
chown 1305:1300   $DATA_ROOT/config/media-arr/unpackerr  && chmod 750 $DATA_ROOT/config/media-arr/unpackerr
chown 1306:1300   $DATA_ROOT/config/media-arr/recyclarr  && chmod 750 $DATA_ROOT/config/media-arr/recyclarr
chown 100000:100000 $DATA_ROOT/config/media-arr/dispatcharr && chmod 750 $DATA_ROOT/config/media-arr/dispatcharr

# Shared media dirs - idempotent, also set by ct301 and ct302
chown root:1300 \
    $DATA_ROOT/media-stack/media/tv \
    $DATA_ROOT/media-stack/media/anime \
    $DATA_ROOT/media-stack/media/movies \
    $DATA_ROOT/media-stack/media/movies-4k \
    $DATA_ROOT/media-stack/torrents \
    $DATA_ROOT/media-stack/torrents/tv \
    $DATA_ROOT/media-stack/torrents/movies \
    $DATA_ROOT/media-stack/usenet \
    $DATA_ROOT/media-stack/usenet/complete \
    $DATA_ROOT/media-stack/usenet/complete/tv \
    $DATA_ROOT/media-stack/usenet/complete/movies \
    $DATA_ROOT/media-stack/usenet/incomplete
chmod 775 \
    $DATA_ROOT/media-stack/media/tv \
    $DATA_ROOT/media-stack/media/anime \
    $DATA_ROOT/media-stack/media/movies \
    $DATA_ROOT/media-stack/media/movies-4k \
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
set_mp $VMID -mp0 $DATA_ROOT/config/media-arr,mp=/data
set_mp $VMID -mp1 $DATA_ROOT/media-stack/media,mp=/media
set_mp $VMID -mp2 $DATA_ROOT/media-stack/torrents,mp=/torrents
set_mp $VMID -mp3 $DATA_ROOT/media-stack/usenet,mp=/usenet

patch_conf $VMID "lxc.idmap" "lxc.idmap: u 0 100000 1000
lxc.idmap: u 1000 1000 500
lxc.idmap: u 1500 101500 64036
lxc.idmap: g 0 100000 1000
lxc.idmap: g 1000 1000 500
lxc.idmap: g 1500 101500 64036"

echo ""
echo "=== Stack files ==="
deploy_stack "$STACKS_DIR/media-arr" "media-arr" \
    SONARR_URL SONARR_API_KEY RADARR_URL RADARR_API_KEY
deploy_stack "$STACKS_DIR/node-exporter-media-arr" "node-exporter"

start_and_install_periphery $VMID /data/komodo
configure_docker_daemon $VMID

echo ""
echo "=== CT $VMID done ==="
