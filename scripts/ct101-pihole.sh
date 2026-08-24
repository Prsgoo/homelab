#!/bin/bash
# CT 101 - pihole
# Run as root on the Proxmox host after creating CT 101.
# Usage: Fill in scripts/.env, then: ./ct101-pihole.sh
# Pi-hole runs natively - no Docker stacks managed by Komodo.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/common.sh"
load_env

VMID=101

echo "=== CT $VMID - pihole ==="

ct_exists $VMID || { echo "ERROR: CT $VMID not found. Create it first." >&2; exit 1; }

echo ""
echo "=== LXC conf patches ==="
patch_conf $VMID "/dev/net/tun" "dev0: /dev/net/tun,gid=0,uid=0"

# No Docker stacks on this CT - no root_directory needed for Periphery
start_and_install_periphery $VMID

echo ""
echo "=== CT $VMID done ==="
