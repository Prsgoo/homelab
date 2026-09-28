#!/bin/bash
# CT 600 - personal-apps (Actual Budget, Mealie, FreshRSS, Grimmory, Grocy)
# Run as root on the Proxmox host after creating CT 600.
# Usage: Fill in scripts/.env, then: ./ct600-personal-apps.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/common.sh"
load_env

VMID=600
STACKS_DIR=$DATA_ROOT/config/personal-apps/komodo/stacks

echo "=== CT $VMID - personal-apps ==="

[ -d $DATA_ROOT ] || { echo "ERROR: $DATA_ROOT not mounted. Run host-prep.sh first." >&2; exit 1; }
ct_exists $VMID || { echo "ERROR: CT $VMID not found. Create it first." >&2; exit 1; }

echo ""
echo "=== Users & groups ==="
add_group 1300 media
add_group 1600 personal-apps
add_user  1600 1600 grimmory
usermod -aG media grimmory
add_user  1601 1600 grocy
add_user  1602 1600 mealie
add_user  1603 1600 freshrss

echo ""
echo "=== Data directory ownership ==="
chown 100000:100000 $DATA_ROOT/config/personal-apps && chmod 755 $DATA_ROOT/config/personal-apps
# Actual Budget image hardcodes UID 1001 - not our naming scheme
mkdir -p $DATA_ROOT/config/personal-apps/actual-budget
chown 1001:1001 $DATA_ROOT/config/personal-apps/actual-budget && chmod 750 $DATA_ROOT/config/personal-apps/actual-budget
# Mealie image runs as UID 911 - maps to host UID 100911 via idmap (CT 0-999 → host 100000-100999)
mkdir -p $DATA_ROOT/config/personal-apps/mealie
chown 100911:100911 $DATA_ROOT/config/personal-apps/mealie && chmod 750 $DATA_ROOT/config/personal-apps/mealie
# Grimmory UID 1600 (personal-apps group)
mkdir -p $DATA_ROOT/config/personal-apps/grimmory/{data,db,bookdrop}
chown 1600:1600 $DATA_ROOT/config/personal-apps/grimmory/data    && chmod 750 $DATA_ROOT/config/personal-apps/grimmory/data
chown 1600:1600 $DATA_ROOT/config/personal-apps/grimmory/db      && chmod 750 $DATA_ROOT/config/personal-apps/grimmory/db
chown 1600:1600 $DATA_ROOT/config/personal-apps/grimmory/bookdrop && chmod 750 $DATA_ROOT/config/personal-apps/grimmory/bookdrop
# Grocy UID 1601 (personal-apps group)
mkdir -p $DATA_ROOT/config/personal-apps/grocy
chown 1601:1600 $DATA_ROOT/config/personal-apps/grocy && chmod 750 $DATA_ROOT/config/personal-apps/grocy
# FreshRSS runs as www-data (UID 33) - CT 600 maps UID 0-999 → host 100000+, so UID 33 → host 100033
mkdir -p $DATA_ROOT/config/personal-apps/freshrss
chown 100033:100033 $DATA_ROOT/config/personal-apps/freshrss && chmod 750 $DATA_ROOT/config/personal-apps/freshrss
# Library media dirs - owned by media group; grimmory accesses via supplementary media group
mkdir -p $DATA_ROOT/media-stack/media/library/{books,comics,manga}
chown root:1300 $DATA_ROOT/media-stack/media/library && chmod 775 $DATA_ROOT/media-stack/media/library
chown root:1300 \
    $DATA_ROOT/media-stack/media/library/books \
    $DATA_ROOT/media-stack/media/library/comics \
    $DATA_ROOT/media-stack/media/library/manga
chmod 775 \
    $DATA_ROOT/media-stack/media/library/books \
    $DATA_ROOT/media-stack/media/library/comics \
    $DATA_ROOT/media-stack/media/library/manga
echo "  done"

echo ""
echo "=== LXC conf patches ==="
set_mp $VMID -mp0 $DATA_ROOT/config/personal-apps,mp=/data
set_mp $VMID -mp1 $DATA_ROOT/media-stack/media/library,mp=/library

patch_conf $VMID "lxc.idmap" "lxc.idmap: u 0 100000 1000
lxc.idmap: u 1000 1000 700
lxc.idmap: u 1700 101700 63836
lxc.idmap: g 0 100000 1000
lxc.idmap: g 1000 1000 700
lxc.idmap: g 1700 101700 63836"

echo ""
echo "=== Stack files ==="
deploy_stack "$STACKS_DIR/actual-budget" "personal-apps/actual-budget"
deploy_stack "$STACKS_DIR/mealie"        "personal-apps/mealie"
deploy_stack "$STACKS_DIR/grocy"         "personal-apps/grocy"
deploy_stack "$STACKS_DIR/freshrss"      "personal-apps/freshrss"
deploy_stack "$STACKS_DIR/grimmory"      "personal-apps/grimmory" GRIMMORY_DB_PASSWORD GRIMMORY_DB_ROOT_PASSWORD

start_and_install_periphery $VMID /data/komodo
configure_docker_daemon $VMID

echo ""
echo "=== CT $VMID done ==="
