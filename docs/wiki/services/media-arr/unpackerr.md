---
title: Unpackerr
updated: 2026-08-05
---

# Unpackerr

LXC: [media arr](../../lxcs/media-arr.md) (CT 300) - automatic extraction of compressed downloads.

## Instance

| Setting | Value |
|---------|-------|
| Config | via environment variables in `.env` |
| UID/GID | 1305:1305 |
| Managed as | Komodo stack `media-arr` |

No HTTP port - Unpackerr runs as a background daemon, polling Sonarr/Radarr for completed downloads and extracting `.rar`/`.zip` archives in the download directories.

## Key Env Vars

| Variable | Purpose |
|----------|---------|
| `UN_SONARR_0_URL` | `http://sonarr:8989` |
| `UN_SONARR_0_API_KEY` | Sonarr API key |
| `UN_RADARR_0_URL` | `http://radarr:7878` |
| `UN_RADARR_0_API_KEY` | Radarr API key |

Internal container names work because Unpackerr is in the same Docker network.
