#!/bin/bash
# CT 200 - ultrafeeder (ADS-B)
# Run as root on the Proxmox host after creating CT 200.
# Usage: Fill in scripts/.env, then: ./ct200-ultrafeeder.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/common.sh"
load_env

VMID=200
STACKS_DIR=$DATA_ROOT/config/ultrafeeder/komodo/stacks

echo "=== CT $VMID - ultrafeeder ==="

[ -d $DATA_ROOT ] || { echo "ERROR: $DATA_ROOT not mounted. Run host-prep.sh first." >&2; exit 1; }
ct_exists $VMID || { echo "ERROR: CT $VMID not found. Create it first." >&2; exit 1; }

echo ""
echo "=== Data directory ownership ==="
# Ultrafeeder runs as root in Docker - no idmap
chown 100000:100000 $DATA_ROOT/config/ultrafeeder && chmod 755 $DATA_ROOT/config/ultrafeeder
echo "  done"

echo ""
echo "=== LXC conf patches ==="
set_mp $VMID -mp0 $DATA_ROOT/config/ultrafeeder,mp=/data

# RTL-SDR USB bus passthrough
patch_conf $VMID "dev/bus/usb" "lxc.cgroup2.devices.allow: c 189:* rwm
lxc.mount.entry: /dev/bus/usb dev/bus/usb none bind,optional,create=dir"

echo ""
echo "=== Stack files ==="
deploy_stack "$STACKS_DIR/ultrafeeder" "ultrafeeder" \
    FEEDER_TZ FEEDER_LAT FEEDER_LONG FEEDER_ALT_M FEEDER_NAME \
    ADSB_SDR_SERIAL ADSB_SDR_PPM ULTRAFEEDER_UUID \
    FEEDER_HEYWHATSTHAT_ID FEEDER_HEYWHATSTHAT_ALTS \
    PIAWARE_FEEDER_ID FR24_SHARING_KEY FR24_SHARING_KEY_UAT \
    OPENSKY_USERNAME OPENSKY_SERIAL
deploy_stack "$STACKS_DIR/node-exporter-ultrafeeder" "node-exporter"

start_and_install_periphery $VMID /data/komodo
configure_docker_daemon $VMID

echo ""
echo "=== CT $VMID done ==="
