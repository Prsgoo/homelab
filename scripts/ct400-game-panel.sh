#!/bin/bash
# CT 400 - game-panel (Pterodactyl Panel)
# Run as root on the Proxmox host after creating CT 400.
# No Docker on this CT - Pterodactyl Panel runs natively (PHP/Apache).
# Usage: Fill in scripts/.env, then: ./ct400-game-panel.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/common.sh"
load_env

VMID=400

echo "=== CT $VMID - game-panel ==="

[ -d $DATA_ROOT ] || { echo "ERROR: $DATA_ROOT not mounted. Run host-prep.sh first." >&2; exit 1; }
ct_exists $VMID || { echo "ERROR: CT $VMID not found. Create it first." >&2; exit 1; }

echo ""
echo "=== Data directory ownership ==="
chown 100000:100000 $DATA_ROOT/config/panel && chmod 755 $DATA_ROOT/config/panel
echo "  done"

echo ""
echo "=== LXC conf patches ==="
set_mp $VMID -mp0 $DATA_ROOT/config/panel,mp=/data
patch_conf $VMID "/dev/net/tun" "dev0: /dev/net/tun,gid=0,uid=0"

# No root_directory - Periphery is for management visibility only (no Docker stacks)
start_and_install_periphery $VMID

echo ""
echo "=== CT $VMID done ==="
