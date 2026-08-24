#!/bin/bash
# CT 202 - monitoring (Prometheus, Grafana, Uptime Kuma)
# Run as root on the Proxmox host after creating CT 202.
# Usage: Fill in scripts/.env, then: ./ct202-monitoring.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/common.sh"
load_env

VMID=202
STACKS_DIR=$DATA_ROOT/config/monitoring/komodo/stacks

echo "=== CT $VMID - monitoring ==="

[ -d $DATA_ROOT ] || { echo "ERROR: $DATA_ROOT not mounted. Run host-prep.sh first." >&2; exit 1; }
ct_exists $VMID || { echo "ERROR: CT $VMID not found. Create it first." >&2; exit 1; }

echo ""
echo "=== Data directory ownership ==="
# No idmap - container root creates its own subdirs
chown 100000:100000 $DATA_ROOT/config/monitoring && chmod 755 $DATA_ROOT/config/monitoring
echo "  done"

echo ""
echo "=== LXC conf patches ==="
set_mp $VMID -mp0 $DATA_ROOT/config/monitoring,mp=/data

echo ""
echo "=== Stack files ==="
deploy_stack "$STACKS_DIR/monitoring"              "monitoring"
deploy_stack "$STACKS_DIR/node-exporter-monitoring" "node-exporter"

start_and_install_periphery $VMID /data/komodo
configure_docker_daemon $VMID

echo ""
echo "=== CT $VMID done ==="
