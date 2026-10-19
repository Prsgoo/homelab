---
title: LXC Inventory
updated: 2026-09-13
---

# LXC Inventory

## Active Containers

| CT | Name | IP | rootfs Pool | Alloc | onboot | Notes |
|----|------|----|-------------|-------|--------|-------|
| 100 | management | 192.168.50.100 | local-lvm | 8GB | yes | Komodo Core + Traefik + Glance + FileBrowser |
| 101 | pihole | 192.168.50.101 | local-lvm | 4GB | yes | Pi-hole + Unbound - DNS + ad blocking |
| 200 | ultrafeeder | 192.168.50.200 | local-lvm | 8GB | yes | ADS-B feeder stack (ultrafeeder + piaware + fr24) |
| 201 | iot | 192.168.50.201 | local-lvm | 8GB | yes | IoT automation (homebridge, zigbee2mqtt, mosquitto) |
| 202 | monitoring | 192.168.50.202 | local-lvm | 8GB | yes | Grafana + Prometheus + pve-exporter |
| 300 | media-arr | 192.168.50.30 | local-lvm | 12GB | yes | Sonarr, Radarr, Prowlarr, Bazarr, Seerr, Flaresolverr, Unpackerr, Recyclarr, Dispatcharr |
| 301 | media-server | 192.168.50.31 | local-lvm | 8GB | yes | Jellyfin + Jellystat media server stack |
| 302 | media-dl | 192.168.50.32 | local-lvm | 8GB | yes | qBittorrent + SABnzbd |
| 303 | media-read | 192.168.50.33 | local-lvm | 8GB | yes | Manga reading stack: Suwayomi |
| 304 | games | 192.168.50.34 | local-lvm | 8GB | yes | RomM game library + MariaDB |
| 400 | game-panel | 192.168.50.40 | local-lvm | 8GB | no | Pterodactyl panel + MariaDB - on-demand, start manually |
| 401 | minecraft-wings | 192.168.50.41 | local-lvm | 16GB | no | Pterodactyl Wings + Docker - on-demand, start manually |
| 600 | personal-apps | 192.168.50.60 | local-lvm | 8GB | yes | Personal apps: Actual Budget, Mealie, FreshRSS, Grimmory |


## Mount Points

| CT | Name | Mount | Host path | Container path |
|----|------|-------|-----------|----------------|
| 100 | management | mp0 | `$DATA_ROOT` | `/data` |
| 100 | management | mp1 | `$DATA_ROOT/minecraft` | `/minecraft` |
| 200 | ultrafeeder | mp0 | `$DATA_ROOT/config/ultrafeeder` | `/data` |
| 201 | iot | mp0 | `$DATA_ROOT/config/iot` | `/data` |
| 300 | media-arr | mp0 | `$DATA_ROOT/config/media-arr` | `/data` |
| 300 | media-arr | mp1 | `$DATA_ROOT/media-stack/media` | `/media` |
| 300 | media-arr | mp2 | `$DATA_ROOT/media-stack/torrents` | `/torrents` |
| 300 | media-arr | mp3 | `$DATA_ROOT/media-stack/usenet` | `/usenet` |
| 202 | monitoring | mp0 | `$DATA_ROOT/config/monitoring` | `/data` |
| 301 | media-server | mp0 | `$DATA_ROOT/config/media-server` | `/data` |
| 301 | media-server | mp1 | `$DATA_ROOT/media-stack/media` | `/media` (ro) |
| 302 | media-dl | mp0 | `$DATA_ROOT/config/media-dl` | `/data` |
| 302 | media-dl | mp1 | `$DATA_ROOT/media-stack/torrents` | `/torrents` |
| 302 | media-dl | mp2 | `$DATA_ROOT/media-stack/usenet` | `/usenet` |
| 303 | media-read | mp0 | `$DATA_ROOT/config/media-read` | `/data` |
| 303 | media-read | mp1 | `$DATA_ROOT/media-stack/media/library/manga` | `/manga` |
| 304 | games | mp0 | `$DATA_ROOT/config/media-games` | `/data` |
| 304 | games | mp1 | `$DATA_ROOT/media-stack/games` | `/library` |
| 400 | game-panel | mp0 | `$DATA_ROOT/config/panel` | `/data` |
| 401 | minecraft-wings | mp0 | `$DATA_ROOT/config/minecraft-wings` | `/data` |
| 401 | minecraft-wings | mp1 | `$DATA_ROOT/minecraft/volumes` | `/var/lib/pterodactyl/volumes` |
| 401 | minecraft-wings | mp2 | `$DATA_ROOT/minecraft/backups` | `/var/lib/pterodactyl/backups` |
| 600 | personal-apps | mp0 | `$DATA_ROOT/config/personal-apps` | `/data` |
| 600 | personal-apps | mp1 | `$DATA_ROOT/media-stack/media/library` | `/library` |

## OS Standard

All LXCs use **Debian 13 (trixie)** - `debian-13-standard_13.1-2_amd64.tar.zst`.

## ID Convention Reference

| Range | Category |
|-------|----------|
| 100–199 | Infrastructure (management, reverse proxy, DNS) |
| 200–299 | IoT & monitoring |
| 300–399 | Media & storage |
| 400–499 | Game servers (panel, wings) |
| 500–599 | Dev / CI (project-specific dev environments and CI runners) |
| 600–699 | Personal apps |
| 900–999 | Dev / testing (temporary) |

## Key Takeaways

- 13 containers total, all rootfs on local-lvm: 100, 101, 200, 201, 202, 300, 301, 302, 303, 304, 400, 401, 600
- CT 400 and CT 401 are on-demand (onboot=no) - start manually when gaming sessions are needed
- Storage pool assignments and thin pool usage: see [storage layout](../storage/storage-layout.md)
