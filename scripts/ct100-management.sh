#!/bin/bash
# CT 100 - management
# Run as root on the Proxmox host after creating CT 100.
# Usage: Fill in scripts/.env, then: ./ct100-management.sh
# Periphery runs as a Docker container inside the Komodo compose - no binary install here.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/common.sh"
load_env

VMID=100
STACKS_DIR=$DATA_ROOT/config/management/komodo/periphery/stacks

echo "=== CT $VMID - management ==="

[ -d $DATA_ROOT ] || { echo "ERROR: $DATA_ROOT not mounted. Run host-prep.sh first." >&2; exit 1; }
ct_exists $VMID || { echo "ERROR: CT $VMID not found. Create it first." >&2; exit 1; }

echo ""
echo "=== Data directory ownership ==="
chown -R 100000:100000 $DATA_ROOT/config/management && chmod -R 755 $DATA_ROOT/config/management
# CT 100 bind-mounts full $DATA_ROOT - needs ACL to traverse root and config/
setfacl -m u:100000:rx $DATA_ROOT
setfacl -m u:100000:rx $DATA_ROOT/config
setfacl -Rm  u:100000:rwx $DATA_ROOT/media-stack
setfacl -Rdm u:100000:rwx $DATA_ROOT/media-stack
echo "  done"

echo ""
echo "=== LXC conf patches ==="
set_mp $VMID -mp0 $DATA_ROOT,mp=/data
set_mp $VMID -mp1 $DATA_ROOT/minecraft,mp=/minecraft
patch_conf $VMID "/dev/net/tun" "dev0: /dev/net/tun,gid=0,uid=0"

echo ""
echo "=== Stack files ==="
deploy_stack "$STACKS_DIR/cloudflared"      "management/cloudflared" CLOUDFLARE_TUNNEL_TOKEN
deploy_stack "$STACKS_DIR/filebrowser"      "management/filebrowser" FILEBROWSER_DATABASE
deploy_stack "$STACKS_DIR/glance"           "management/glance"      PVE_API_TOKEN PIHOLE_PASSWORD
deploy_stack "$STACKS_DIR/traefik"          "management/traefik"     CLOUDFLARE_DNS_API_TOKEN
deploy_stack "$STACKS_DIR/node-exporter-local" "node-exporter"

echo ""
echo "=== CT $VMID done ==="
echo "    Periphery runs as a Docker container inside the Komodo compose."
echo "    Start CT 100, deploy the Komodo stack, then verify Periphery appears in the UI."
