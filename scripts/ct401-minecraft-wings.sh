#!/bin/bash
# CT 401 - minecraft-wings (Pterodactyl Wings)
# Run as root on the Proxmox host after creating CT 401.
# Wings manages its own Docker containers - Komodo does not manage stacks here.
# Usage: Fill in scripts/.env, then: ./ct401-minecraft-wings.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/common.sh"
load_env

VMID=401

echo "=== CT $VMID - minecraft-wings ==="

[ -d $DATA_ROOT ] || { echo "ERROR: $DATA_ROOT not mounted. Run host-prep.sh first." >&2; exit 1; }
[ -d $DATA_ROOT/minecraft ] || { echo "ERROR: $DATA_ROOT/minecraft not mounted. Run host-prep.sh with MINECRAFT_DISK set." >&2; exit 1; }
ct_exists $VMID || { echo "ERROR: CT $VMID not found. Create it first." >&2; exit 1; }

echo ""
echo "=== Data directory ownership ==="
chown 100000:100000 $DATA_ROOT/config/minecraft-wings && chmod 755 $DATA_ROOT/config/minecraft-wings
echo "  done"

echo ""
echo "=== LXC conf patches ==="
set_mp $VMID -mp0 $DATA_ROOT/config/minecraft-wings,mp=/data
set_mp $VMID -mp1 $DATA_ROOT/minecraft/volumes,mp=/var/lib/pterodactyl/volumes
set_mp $VMID -mp2 $DATA_ROOT/minecraft/backups,mp=/var/lib/pterodactyl/backups
patch_conf $VMID "/dev/net/tun" "dev0: /dev/net/tun,gid=0,uid=0"

# No root_directory - Periphery is for management visibility only
start_and_install_periphery $VMID

echo ""
echo "=== CT $VMID done ==="
