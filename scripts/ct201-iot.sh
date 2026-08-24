#!/bin/bash
# CT 201 - iot (Homebridge, Zigbee2MQTT, Mosquitto)
# Run as root on the Proxmox host after creating CT 201.
# Usage: Fill in scripts/.env, then: ./ct201-iot.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/common.sh"
load_env

VMID=201
STACKS_DIR=$DATA_ROOT/config/iot/komodo/stacks

echo "=== CT $VMID - iot ==="

[ -d $DATA_ROOT ] || { echo "ERROR: $DATA_ROOT not mounted. Run host-prep.sh first." >&2; exit 1; }
ct_exists $VMID || { echo "ERROR: CT $VMID not found. Create it first." >&2; exit 1; }

echo ""
echo "=== Users & groups ==="
add_group 1200 iot
add_user  1200 1200 homebridge
add_user  1201 1200 zigbee2mqtt
add_user  1202 1200 mosquitto

echo ""
echo "=== Data directory ownership ==="
chown 100000:1200 $DATA_ROOT/config/iot          && chmod 750 $DATA_ROOT/config/iot
chown 1200:1200   $DATA_ROOT/config/iot/homebridge  && chmod 750 $DATA_ROOT/config/iot/homebridge
chown 1201:1200   $DATA_ROOT/config/iot/zigbee2mqtt && chmod 750 $DATA_ROOT/config/iot/zigbee2mqtt
chown 1202:1200   $DATA_ROOT/config/iot/mosquitto   && chmod 750 $DATA_ROOT/config/iot/mosquitto
echo "  done"

echo ""
echo "=== LXC conf patches ==="
set_mp $VMID -mp0 $DATA_ROOT/config/iot,mp=/data

patch_conf $VMID "lxc.idmap" "lxc.idmap: u 0 100000 1000
lxc.idmap: u 1000 1000 500
lxc.idmap: u 1500 101500 64036
lxc.idmap: g 0 100000 1000
lxc.idmap: g 1000 1000 500
lxc.idmap: g 1500 101500 64036"

# Zigbee USB serial dongle - update device path if yours differs
patch_conf $VMID "ttyUSB0" "dev0: /dev/ttyUSB0,gid=1200,uid=0"

echo ""
echo "=== Stack files ==="
deploy_stack "$STACKS_DIR/iot"              "iot"
deploy_stack "$STACKS_DIR/node-exporter-iot" "node-exporter"

start_and_install_periphery $VMID /data/komodo
configure_docker_daemon $VMID

echo ""
echo "=== CT $VMID done ==="
