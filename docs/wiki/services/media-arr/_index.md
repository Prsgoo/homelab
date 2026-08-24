---
title: Media Arr Services
---

# Media Arr Services (CT 300)

LXC: [media arr](../../lxcs/media-arr.md)

| Service | Article | Port |
|---------|---------|------|
| Sonarr | [sonarr](sonarr.md) | 8989 |
| Radarr | [radarr](radarr.md) | 7878 |
| Prowlarr | [prowlarr](prowlarr.md) | 9696 |
| Bazarr | [bazarr](bazarr.md) | 6767 |
| Seerr | [seerr](seerr.md) | 5055 |
| Dispatcharr | [dispatcharr](dispatcharr.md) | 9191 |
| Recyclarr | [recyclarr](recyclarr.md) | - |
| Unpackerr | [unpackerr](unpackerr.md) | - |
| FlareSolverr | [flaresolverr](flaresolverr.md) | 8191 (internal) |

## Secrets / .env

All service API keys and credentials are stored in `stacks/media-arr/.env` (not committed). An `.env.example` documents the required keys without values.

## Updating Without Resizing rootfs

CT 300's rootfs is 16GB. Docker image updates consume temp space. To update without risking a full disk:

1. Pull a single image at a time:
   ```bash
   docker compose pull <service>
   ```
2. Stop the old container and start with the new image:
   ```bash
   docker compose up -d <service>
   ```
3. Prune dangling images after each service:
   ```bash
   docker image prune -f
   ```

Full `docker compose pull` + `up -d` can fill rootfs if multiple large images are pulled simultaneously.

## Hardlinks

CT 300 mounts `$DATA_ROOT/media` → `/media` and CT 302 mounts `$DATA_ROOT/torrents` → `/torrents` and `$DATA_ROOT/usenet` → `/usenet`. Because these all come from the same host filesystem (`$DATA_ROOT`), hardlinks between download categories and media libraries work - one file, two directory entries, zero extra disk space.

Sonarr and Radarr must be configured to use hardlinks (not copy) for imports. Verify with: `Settings → Media Management → Use Hardlinks Instead of Copy`.
