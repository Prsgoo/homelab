#!/bin/bash
# CT 303 - media-read (Suwayomi, Komga, Komf)
# Run as root on the Proxmox host after creating CT 303.
# Usage: Fill in scripts/.env, then: ./ct303-media-read.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/common.sh"
load_env

VMID=303
STACKS_DIR=$DATA_ROOT/config/media-read/komodo/stacks

echo "=== CT $VMID - media-read ==="

[ -d $DATA_ROOT ] || { echo "ERROR: $DATA_ROOT not mounted. Run host-prep.sh first." >&2; exit 1; }
ct_exists $VMID || { echo "ERROR: CT $VMID not found. Create it first." >&2; exit 1; }

echo ""
echo "=== Users & groups ==="
add_group 1300 media
# Reserved UIDs for normalization; Suwayomi actually runs as UID 1000 (see service-uid-exceptions.md)
add_user  1330 1300 suwayomi
add_user  1331 1300 komga
add_user  1332 1300 komf

echo ""
echo "=== Data directory ownership ==="
chown 100000:1300 $DATA_ROOT/config/media-read && chmod 750 $DATA_ROOT/config/media-read
# Suwayomi hardcodes UID 1000 - CT 303 idmap passes it 1:1, so host UID 1000 owns this dir
chown 1000:1300   $DATA_ROOT/config/media-read/suwayomi && chmod 750 $DATA_ROOT/config/media-read/suwayomi
chown 1331:1300   $DATA_ROOT/config/media-read/komga    && chmod 750 $DATA_ROOT/config/media-read/komga
chown 1332:1300   $DATA_ROOT/config/media-read/komf     && chmod 750 $DATA_ROOT/config/media-read/komf

# Manga dir - idempotent, owned by media group; also set by ct600
chown root:1300 $DATA_ROOT/media-stack/media/library/manga
chmod 775       $DATA_ROOT/media-stack/media/library/manga
echo "  done"

echo ""
echo "=== LXC conf patches ==="
set_mp $VMID -mp0 $DATA_ROOT/config/media-read,mp=/data
set_mp $VMID -mp1 $DATA_ROOT/media-stack/media/library/manga,mp=/manga

patch_conf $VMID "lxc.idmap" "lxc.idmap: u 0 100000 1000
lxc.idmap: u 1000 1000 500
lxc.idmap: u 1500 101500 64036
lxc.idmap: g 0 100000 1000
lxc.idmap: g 1000 1000 500
lxc.idmap: g 1500 101500 64036"

echo ""
echo "=== Stack files ==="
deploy_stack "$STACKS_DIR/media-read"              "media-read" KOMGA_USER KOMGA_PASSWORD
deploy_stack "$STACKS_DIR/node-exporter-media-read" "node-exporter"

start_and_install_periphery $VMID /data/komodo
configure_docker_daemon $VMID

echo ""
echo "=== CT $VMID done ==="
echo "    Next: in Komga UI, add /manga as a library."
echo "    Then: in Komf, configure metadata providers and link to Komga."
