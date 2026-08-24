#!/bin/bash
# Host-level setup - run once on a fresh Proxmox host before creating any LXCs.
# Idempotent - safe to re-run.
# Run as root.
#
# What this does:
#   - Mounts the data disk and registers the pvesm pool
#   - Creates the full directory tree under $DATA_ROOT
#   - Creates shared host groups (iot, ultrafeeder, media, gaming)
#   - Sets up the Zigbee USB udev rule
#
# After this script finishes, create your LXCs and run the per-CT scripts.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/common.sh"
load_env

# ─── CONFIG ──────────────────────────────────────────────────────────────────
# Adjust to match your hardware. Run `lsblk` to find your disk device.
DATA_DISK="${DATA_DISK:-/dev/sdb1}"
# DATA_ROOT comes from scripts/.env - set it there before running this script.
# ─────────────────────────────────────────────────────────────────────────────

echo "=== [1/5] Data disk ($DATA_DISK) ==="

if ! blkid "$DATA_DISK" &>/dev/null; then
    echo "ERROR: $DATA_DISK not found. Run lsblk and set DATA_DISK to the correct device." >&2
    exit 1
fi

mkdir -p $DATA_ROOT
DATA_UUID=$(blkid -s UUID -o value "$DATA_DISK")

if ! grep -q "$DATA_UUID" /etc/fstab; then
    echo "UUID=$DATA_UUID  $DATA_ROOT  ext4  defaults,nofail  0  2" >> /etc/fstab
    echo "  added to fstab"
fi

mountpoint -q $DATA_ROOT && echo "  already mounted" || { mount $DATA_ROOT && echo "  mounted"; }

if pvesm status | grep -q '^data '; then
    echo "  pvesm pool 'data' already exists"
else
    pvesm add dir data --path $DATA_ROOT --content images,rootdir,snippets
    echo "  created pvesm pool: data"
fi

echo ""
echo "=== [2/4] Directory tree ==="

# Config dirs - one per LXC
for dir in management ultrafeeder iot monitoring media-arr media-server media-dl panel minecraft-wings personal-apps; do
    mkdir -p "$DATA_ROOT/config/$dir"
done

# Media stack - shared across CT 300, 301, 302
for dir in media/tv media/anime media/movies media/movies-4k \
           torrents/tv torrents/movies \
           usenet/complete/tv usenet/complete/movies usenet/incomplete; do
    mkdir -p "$DATA_ROOT/media-stack/$dir"
done

# Pre-create subdirs for idmap LXCs - container root can't create these
# because the bind mount root is owned 100000:gid/750 on the host
mkdir -p "$DATA_ROOT/config/iot"/{homebridge,zigbee2mqtt,mosquitto}
mkdir -p "$DATA_ROOT/config/media-arr"/{sonarr,radarr,prowlarr,bazarr,seerr,dispatcharr,unpackerr,recyclarr}
mkdir -p "$DATA_ROOT/config/media-server/jellyfin"
mkdir -p "$DATA_ROOT/config/media-dl"/{qbittorrent,sabnzbd}
mkdir -p "$DATA_ROOT/config/personal-apps/actual-budget"

# Game server data - Wings bind-mounts these
mkdir -p "$DATA_ROOT/minecraft/volumes" "$DATA_ROOT/minecraft/backups"
chown 100000:100000 "$DATA_ROOT/minecraft/volumes" && chmod 755 "$DATA_ROOT/minecraft/volumes"
chown 100000:100000 "$DATA_ROOT/minecraft/backups" && chmod 755 "$DATA_ROOT/minecraft/backups"

echo "  done"

echo ""
echo "=== [3/4] Shared host groups ==="

add_group 1200 iot
add_group 1210 ultrafeeder
add_group 1300 media
add_group 1400 gaming

echo ""
echo "=== [4/4] Zigbee udev rule ==="

# idVendor/idProduct are for the SiLabs CP210x chipset (Sonoff/ITead dongles).
# Verify yours with: lsusb - then update ATTRS values if different.
if [ ! -f /etc/udev/rules.d/99-zigbee.rules ]; then
    echo 'SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", SYMLINK+="zigbee", GROUP="iot", MODE="0660"' \
        > /etc/udev/rules.d/99-zigbee.rules
    udevadm control --reload-rules
    echo "  created"
else
    echo "  skip (already exists)"
fi

echo ""
echo "=== Host ready ==="
echo "    Create your LXCs, then run the per-CT scripts."
