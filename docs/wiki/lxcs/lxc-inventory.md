---
title: LXC Inventory
updated: 2026-09-13
---

# LXC Inventory

## Active Containers

| CT | Name | IP | rootfs Pool | Alloc | onboot | Notes |
|----|------|----|-------------|-------|--------|-------|
| 100 | management | `<mgmt-ip>` | local-lvm | 8GB | yes | Komodo Core + Traefik + Glance + FileBrowser |
| 101 | pihole | `<pihole-ip>` | local-lvm | 4GB | yes | Pi-hole + Unbound - DNS + ad blocking |
| 200 | ultrafeeder | `<ultrafeeder-ip>` | local-lvm | 8GB | yes | ADS-B feeder stack (ultrafeeder + piaware + fr24) |
| 201 | iot | `<iot-ip>` | local-lvm | 8GB | yes | IoT automation (homebridge, zigbee2mqtt, mosquitto) |
| 202 | monitoring | `<monitoring-ip>` | local-lvm | 8GB | yes | Grafana + Prometheus + pve-exporter |
| 300 | media-arr | `<media-arr-ip>` | local-lvm | 12GB | yes | Sonarr, Radarr, Prowlarr, Bazarr, Seerr, Flaresolverr, Unpackerr, Recyclarr, Dispatcharr |
| 301 | media-server | `<media-server-ip>` | local-lvm | 8GB | yes | Jellyfin + Jellystat media server stack |
| 302 | media-dl | `<media-dl-ip>` | local-lvm | 8GB | yes | qBittorrent + SABnzbd |
| 400 | game-panel | `<panel-ip>` | local-lvm | 8GB | no | Pterodactyl panel + MariaDB - on-demand, start manually |
| 401 | minecraft-wings | `<wings-ip>` | local-lvm | 16GB | no | Pterodactyl Wings + Docker - on-demand, start manually |
| 600 | personal-apps | `<personal-apps-ip>` | local-lvm | 8GB | yes | Personal apps: Actual Budget, Mealie, FreshRSS, Grimmory |


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
| 400 | game-panel | mp0 | `$DATA_ROOT/config/panel` | `/data` |
| 401 | minecraft-wings | mp0 | `$DATA_ROOT/config/minecraft-wings` | `/data` |
| 401 | minecraft-wings | mp1 | `$DATA_ROOT/minecraft/volumes` | `/var/lib/pterodactyl/volumes` |
| 401 | minecraft-wings | mp2 | `$DATA_ROOT/minecraft/backups` | `/var/lib/pterodactyl/backups` |
| 600 | personal-apps | mp0 | `$DATA_ROOT/config/personal-apps` | `/data` |
| 600 | personal-apps | mp1 | `$DATA_ROOT/media-stack/media/books` | `/books` |

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

- 11 containers total, all rootfs on local-lvm: 100, 101, 200, 201, 202, 300, 301, 302, 400, 401, 600
- CT 400 and CT 401 are on-demand (onboot=no) - start manually when gaming sessions are needed
- Storage pool assignments and thin pool usage: see [storage layout](../storage/storage-layout.md)
