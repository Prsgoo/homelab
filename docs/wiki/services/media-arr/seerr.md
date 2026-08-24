---
title: Seerr
updated: 2026-08-05
---

# Seerr

LXC: [media arr](../../lxcs/media-arr.md) (CT 300) - media request and discovery frontend.

## Instance

| Setting | Value |
|---------|-------|
| Port | 5055 |
| Config | `/data/seerr/` |
| UID/GID | `1000:1000` (hardcoded in image - not the reserved 1304) |
| URL | `https://seerr.home.example.com` (user-facing, `:443`) |
| Managed as | Komodo stack `media-arr` |

The Seerr image ignores `PUID`/`PGID` and runs as `node` (UID 1000). The config directory must be pre-owned `1000:1000` inside the LXC (host-side: `100000:100000` due to idmap).

## Integrations

| Service | Config Location |
|---------|----------------|
| Jellyfin | Settings → Media Servers - `http://<media-server-ip>:8096` + API key |
| Sonarr | Settings → Services - `http://sonarr:8989` + API key |
| Radarr | Settings → Services - `http://radarr:7878` + API key |

Internal service names work because Seerr is in the same Docker network as Sonarr/Radarr.

## Key Takeaways

- Seerr is the only media-arr service on `:443` (user-facing) - others are admin-only at `:<admin-port>`
- Config dir ownership must be `1000:1000` in-container - not the idmap UID scheme used by other services
