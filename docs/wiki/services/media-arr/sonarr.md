---
title: Sonarr
updated: 2026-08-05
---

# Sonarr

LXC: [media arr](../../lxcs/media-arr.md) (CT 300) - TV show library manager.

## Instance

| Setting | Value |
|---------|-------|
| Port | 8989 |
| Config | `/data/sonarr/` |
| UID/GID | 1300:1300 |
| URL | `https://sonarr.home.example.com:<admin-port>` |
| Managed as | Komodo stack `media-arr` |

## Root Folders

| Path | Content | Quality Profile |
|------|---------|----------------|
| `/media/tv/` | TV shows | WEB-1080p |
| `/media/anime/` | Anime | Anime Remux 1080p |

## Download Client

qBittorrent at `<media-dl-ip>:8080`, category `sonarr`.

## Integrations

- Prowlarr: indexer sync (sync profile covers all indexers)
- Bazarr: subtitle sync (Sonarr API key configured in Bazarr)
- Jellyfin: library refresh on import (via Jellyfin connection in Sonarr settings)
- Unpackerr: watches for completed downloads requiring extraction

## Key Takeaways

- Use hardlinks for import (not copy) - see [media arr](_index.md)
- Root folder paths inside the container must match what qBittorrent's category paths resolve to on the same host filesystem
