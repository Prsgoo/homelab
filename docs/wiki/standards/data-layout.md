---
title: $DATA_ROOT Layout
updated: 2026-07-31
---

# $DATA_ROOT Layout

Reference for what lives where on the `data` pool (2TB, `$DATA_ROOT`).


## Top-Level Structure

```
$DATA_ROOT/
  config/        Per-LXC service configs
    management/      CT 100 - Komodo, Traefik, Glance, FileBrowser, cloudflared
    ultrafeeder/     CT 200 - globe_history, graphs1090
    iot/             CT 201 - homebridge, zigbee2mqtt, mosquitto
    monitoring/      CT 202 - grafana, prometheus, pve-exporter
    media-arr/       CT 300 - Sonarr, Radarr, Prowlarr, Bazarr, Seerr, Recyclarr, Dispatcharr
    media-server/    CT 301 - Jellyfin
    media-dl/        CT 302 - qBittorrent, SABnzbd
    panel/           CT 400 - Pterodactyl panel, MariaDB, Komodo Periphery
    minecraft-wings/ CT 401 - Wings config (symlinked to /etc/pterodactyl inside container)
    personal-apps/   CT 600 - personal apps
      actual-budget/   Actual Budget data
  media-stack/
    media/         Shared media library
      tv/            Regular TV series (WEB-1080p)
      anime/         Anime series (Anime Remux 1080p)
      movies/        Movies 1080p (Remux+WEB)
      movies-4k/     Movies 4K (Remux+WEB 2160p)
    torrents/      Torrent downloads (qBittorrent → Sonarr/Radarr hardlink source)
      tv/            Sonarr category
      movies/        Radarr category
    usenet/        Usenet downloads (SABnzbd → Sonarr/Radarr hardlink source)
      complete/
        tv/          Sonarr category
        movies/      Radarr category
      incomplete/    In-progress downloads
```

## Bind Mount Map

Shows which LXC gets which $DATA_ROOT subdirectory and at what path inside the container.

| LXC | Host path | Container path | Access |
|-----|-----------|----------------|--------|
| management (CT 100) | `$DATA_ROOT/` | `/data/` | Full data pool - Komodo, Traefik, Glance, FileBrowser |
| ultrafeeder (CT 200) | `$DATA_ROOT/config/ultrafeeder/` | `/data/` | globe_history, graphs1090 |
| media-arr (CT 300) | `$DATA_ROOT/config/media-arr/` | `/data/` | All arr service configs + Komodo root |
| media-arr (CT 300) | `$DATA_ROOT/media-stack/media/` | `/media/` | Shared media library (read/write) |
| media-arr (CT 300) | `$DATA_ROOT/media-stack/torrents/` | `/torrents/` | Torrent download area (read/write) |
| media-arr (CT 300) | `$DATA_ROOT/media-stack/usenet/` | `/usenet/` | Usenet download area (read/write) |
| media-server (CT 301) | `$DATA_ROOT/config/media-server/` | `/data/` | Jellyfin config + Komodo root |
| media-server (CT 301) | `$DATA_ROOT/media-stack/media/` | `/media/` | Shared media library (read-only) |
| media-dl (CT 302) | `$DATA_ROOT/config/media-dl/` | `/data/` | qBittorrent + SABnzbd config + Komodo root |
| media-dl (CT 302) | `$DATA_ROOT/media-stack/torrents/` | `/torrents/` | Torrent download area (read/write) |
| media-dl (CT 302) | `$DATA_ROOT/media-stack/usenet/` | `/usenet/` | Usenet download area (read/write) |
| game-panel (CT 400) | `$DATA_ROOT/config/panel/` | `/data/` | Pterodactyl panel, MariaDB, Komodo Periphery |
| minecraft-wings (CT 401) | `$DATA_ROOT/config/minecraft-wings/` | `/data/` | Wings config (via /etc/pterodactyl symlink) |
| personal-apps (CT 600) | `$DATA_ROOT/config/personal-apps/` | `/data/` | Actual Budget data |
| iot (CT 201) | `$DATA_ROOT/config/iot/` | `/data/` | homebridge, zigbee2mqtt, mosquitto configs |
| monitoring (CT 202) | `$DATA_ROOT/config/monitoring/` | `/data/` | grafana, prometheus, pve-exporter configs |

> minecraft-wings also has a second bind mount from the minecraft pool: `$DATA_ROOT/minecraft/volumes/` → `/var/lib/pterodactyl/volumes/`. Game world data lives there, not on $DATA_ROOT.

Least-privilege: each LXC only gets the subdirs it actually needs.

## Adding a New LXC / Service

1. Create the host directory on $DATA_ROOT before starting the container
2. Set correct ownership per [user group scheme](user-group-scheme.md)
3. Add the idmap block to the LXC config per [lxc idmap](lxc-idmap.md) (if service-owned bind mount)
4. Declare the bind mount in the LXC config (`mp0`, `mp1`, etc.)
5. Document the new row in the bind mount table above

## Key Takeaways

- Never store persistent service data inside the LXC rootfs - always bind-mount from $DATA_ROOT
- Each LXC only gets the $DATA_ROOT subdirs it actually needs (least privilege)
- Host-side directory ownership uses the same UIDs as inside the container - this only works correctly with the lxc.idmap block (see [lxc idmap](lxc-idmap.md))
- See [user group scheme](user-group-scheme.md) for ownership and permissions on each directory
