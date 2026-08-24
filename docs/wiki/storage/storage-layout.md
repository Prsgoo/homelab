---
title: Storage Layout
updated: 2026-08-05
---

# Storage Layout

## Physical Disks

| Device | Size | Mount | Role |
|--------|------|-------|------|
| `/dev/sdc` | 120GB | LVM (`/`) | Proxmox OS + local-lvm thin pool |
| `/dev/sdb` | 2TB | `$DATA_ROOT` | App configs, media, persistent data |
| `/dev/sda` | 1TB | `$DATA_ROOT/minecraft` | Game server worlds |

## Proxmox Storage Pools

| Pool | Type | Total | Path / Config |
|------|------|-------|---------------|
| `local` | dir | 36.8GB | `/var/lib/vz` - templates, ISOs, backups |
| `local-lvm` | lvmthin | 63.1GB | VG `pve`, thin pool `data` on `/dev/sdc3` - VG fully allocated (0 free extents) |
| `data` | dir | 1.83TB | `$DATA_ROOT` on `/dev/sdb1` - bind-mount data for all LXCs |
| `minecraft` | dir | 916GB | `$DATA_ROOT/minecraft` on `/dev/sda1` - game server data |


## local-lvm Volume Inventory

| Volume | Size | Used by |
|--------|------|---------|
| `vm-100-disk-0` | 8GB | CT 100 (management) - Komodo + Traefik + Glance + FileBrowser |
| `vm-101-disk-0` | 4GB | CT 101 (pihole) - Pi-hole + Unbound |
| `vm-200-disk-0` | 8GB | CT 200 (ultrafeeder) - ADS-B feeder stack |
| `vm-201-disk-0` | 8GB | CT 201 (iot) - homebridge, zigbee2mqtt, mosquitto |
| `vm-202-disk-0` | 8GB | CT 202 (monitoring) - Grafana + Prometheus + pve-exporter |
| `vm-300-disk-0` | 16GB | CT 300 (media-arr) - Sonarr, Radarr, Prowlarr, Bazarr, Seerr, Recyclarr, Dispatcharr |
| `vm-301-disk-0` | 8GB | CT 301 (media-server) - Jellyfin + Jellystat |
| `vm-302-disk-0` | 8GB | CT 302 (media-dl) - qBittorrent + SABnzbd |
| `vm-400-disk-0` | 8GB | CT 400 (game-panel) - Pterodactyl panel |
| `vm-401-disk-0` | 16GB | CT 401 (minecraft-wings) - Wings + Docker |
| `vm-600-disk-0` | 4GB | CT 600 (personal-apps) - Actual Budget |

**Thin-allocated: 96GB on a 63.1GB thin pool.** LVM thin pools allow overcommit - 63.1GB is the hard limit on actual writes, not on allocated size. Run `lvs -a --units g -o lv_name,vg_name,lv_size,data_percent,metadata_percent` on the host to check current pool fill.

## data Pool Contents

| Path | Size | Used by |
|------|------|---------|
| `$DATA_ROOT/config/management/` | ~2GB | CT 100 - Komodo, Traefik, Glance, FileBrowser, cloudflared configs |
| `$DATA_ROOT/config/ultrafeeder/` | ~1GB | CT 200 - globe_history, graphs1090 |
| `$DATA_ROOT/config/iot/` | small | CT 201 - homebridge, zigbee2mqtt, mosquitto |
| `$DATA_ROOT/config/monitoring/` | small | CT 202 - Grafana + Prometheus data |
| `$DATA_ROOT/config/media-arr/` | ~1GB | CT 300 - Sonarr, Radarr, Prowlarr, Bazarr, Seerr, Recyclarr configs |
| `$DATA_ROOT/config/media-server/` | ~1GB | CT 301 - Jellyfin metadata and config |
| `$DATA_ROOT/config/media-dl/` | small | CT 302 - qBittorrent + SABnzbd config |
| `$DATA_ROOT/config/panel/` | ~1GB | CT 400 - Pterodactyl panel, MariaDB |
| `$DATA_ROOT/config/minecraft-wings/` | small | CT 401 - Wings config |
| `$DATA_ROOT/config/personal-apps/` | small | CT 600 - Actual Budget data |
| `$DATA_ROOT/media-stack/media/` | growing | Shared media library (movies, TV, anime) - written by CT 300, read-only for CT 301 |
| `$DATA_ROOT/media-stack/torrents/` | growing | Active download area - CT 302 writes, CT 300 hardlinks from here |
| `$DATA_ROOT/media-stack/usenet/` | growing | Usenet download area - SABnzbd writes, CT 300 hardlinks from here |

## minecraft Pool Contents

| Path | Used by |
|------|---------|
| `$DATA_ROOT/minecraft/volumes/` | CT 401 bind-mount - game server world data |
| `$DATA_ROOT/minecraft/backups/` | CT 401 bind-mount - Pterodactyl server backups |

## Key Takeaways

- local-lvm: 96GB thin-allocated on a 63.1GB pool - overcommit is expected; the pool limit is on actual writes, not allocated size. Run `lvs` to check real fill before resizing any rootfs
- Weekly `pct fstrim` cron (`/etc/cron.d/fstrim-containers`, Sundays 03:00) reclaims deleted-but-untrimmed Docker blocks automatically - see [cheatsheet](../ops/cheatsheet.md)
- VG `pve` has 0 free extents - local-lvm cannot grow further without adding a new physical disk to the VG
- `data` pool: 1.83TB on `$DATA_ROOT` - will grow as the media library fills
- `minecraft` pool: 916GB on `$DATA_ROOT/minecraft` - game server worlds and backups
- Storage rule for new containers: rootfs on local-lvm, persistent data as bind mounts from `data` pool
- All container data is under `config/<name>/` - see [data layout](../standards/data-layout.md)
- **Rootfs resize gotcha:** always run `pct fstrim` on all containers before resizing a rootfs - if the thin pool is near full, the resize can succeed at the LV-metadata level while the filesystem resize fails on boot. After growing the LV, the offline sequence is: `pct stop` → `e2fsck -f /dev/pve/<vol>` → `resize2fs /dev/pve/<vol>` → `pct start`
