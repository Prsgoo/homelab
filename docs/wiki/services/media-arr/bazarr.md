---
title: Bazarr
updated: 2026-08-05
---

# Bazarr

LXC: [media arr](../../lxcs/media-arr.md) (CT 300) - subtitle manager for Sonarr and Radarr libraries.

## Instance

| Setting | Value |
|---------|-------|
| Port | 6767 |
| Config | `/data/bazarr/` |
| UID/GID | 1303:1303 |
| URL | `https://bazarr.home.example.com:<admin-port>` |
| Managed as | Komodo stack `media-arr` |

Configured with Sonarr and Radarr API keys for library path mapping and automatic subtitle fetching on import.
