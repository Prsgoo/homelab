---
title: qBittorrent
updated: 2026-08-05
---

# qBittorrent

LXC: [media dl](../../lxcs/media-dl.md) (CT 302) - BitTorrent client.

## Instance

| Setting | Value |
|---------|-------|
| Port | 8080 |
| Config | `/data/qbittorrent/` |
| UID/GID | 1320:1320 |
| URL | `https://downloads.home.example.com:<admin-port>` |
| Managed as | Komodo stack `media-dl` |

## Download Categories

| Category | Save Path |
|----------|-----------|
| `sonarr` | `/torrents/tv/` |
| `radarr` | `/torrents/movies/` |

## Seeding Config

- Ratio limit: `1.0`
- When ratio reached: **Pause** (not Remove - allows manual review before deletion)

## DNS Override

```yaml
dns:
  - 1.1.1.1
  - 8.8.8.8
```

Required - Pi-hole blocks many tracker domains.

## Sonarr/Radarr Connection

Sonarr and Radarr connect to qBittorrent at `<media-dl-ip>:8080` (not by Docker name - they run on separate LXCs).
