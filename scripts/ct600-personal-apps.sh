#!/bin/bash
# CT 600 - personal-apps (Actual Budget)
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
echo "=== Data directory ownership ==="
chown 100000:100000 $DATA_ROOT/config/personal-apps && chmod 755 $DATA_ROOT/config/personal-apps
# Actual Budget image hardcodes UID 1001 - not our naming scheme
mkdir -p $DATA_ROOT/config/personal-apps/actual-budget
chown 1001:1001 $DATA_ROOT/config/personal-apps/actual-budget && chmod 750 $DATA_ROOT/config/personal-apps/actual-budget
# Mealie image runs as UID 911 - maps to host UID 100911 via idmap (CT 0-999 → host 100000-100999)
mkdir -p $DATA_ROOT/config/personal-apps/mealie
chown 100911:100911 $DATA_ROOT/config/personal-apps/mealie && chmod 750 $DATA_ROOT/config/personal-apps/mealie
echo "  done"

echo ""
echo "=== LXC conf patches ==="
set_mp $VMID -mp0 $DATA_ROOT/config/personal-apps,mp=/data

patch_conf $VMID "lxc.idmap" "lxc.idmap: u 0 100000 1000
lxc.idmap: u 1000 1000 500
lxc.idmap: u 1500 101500 64036
lxc.idmap: g 0 100000 1000
lxc.idmap: g 1000 1000 500
lxc.idmap: g 1500 101500 64036"

echo ""
echo "=== Stack files ==="
deploy_stack "$STACKS_DIR/actual-budget" "personal-apps/actual-budget"
deploy_stack "$STACKS_DIR/mealie"         "personal-apps/mealie"

start_and_install_periphery $VMID /data/komodo
configure_docker_daemon $VMID

echo ""
echo "=== CT $VMID done ==="
