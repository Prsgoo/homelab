---
title: Radarr
updated: 2026-08-05
---

# Radarr

LXC: [media arr](../../lxcs/media-arr.md) (CT 300) - movie library manager.

## Instance

| Setting | Value |
|---------|-------|
| Port | 7878 |
| Config | `/data/radarr/` |
| UID/GID | 1301:1301 |
| URL | `https://radarr.home.example.com:<admin-port>` |
| Managed as | Komodo stack `media-arr` |

## Root Folders

| Path | Content | Quality Profile |
|------|---------|----------------|
| `/media/movies/` | Movies | Remux+WEB 1080p |
| `/media/movies-4k/` | 4K Movies | Remux+WEB 2160p |

## Download Client

qBittorrent at `<media-dl-ip>:8080`, category `radarr`.

## Integrations

- Prowlarr: indexer sync
- Bazarr: subtitle sync
- Seerr: request management (Radarr API key in Seerr settings)
- Jellyfin: library refresh on import
- Unpackerr: extraction of compressed downloads
