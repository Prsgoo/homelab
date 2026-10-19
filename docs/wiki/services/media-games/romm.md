---
title: RomM
updated: 2026-09-29
---

# RomM

Self-hosted game library manager. Supports ROM files for retro platforms and file-less catalog entries for modern platforms (Steam, Xbox, physical). Multi-user with per-user game state, saves, and screenshots.

## Details

| Setting | Value |
|---------|-------|
| LXC | CT 304 (games) |
| Image | `rommapp/romm:latest` |
| DB Image | `mariadb:latest` |
| Port | 3000 (maps to internal 8080) |
| Assets | `/data/romm/assets` → `$DATA_ROOT/config/media-games/romm/assets` |
| Config | `/data/romm/config` → `$DATA_ROOT/config/media-games/romm/config` |
| Redis cache | `/data/romm/redis` → `$DATA_ROOT/config/media-games/romm/redis` |
| DB | `/data/mariadb` → `$DATA_ROOT/config/media-games/mariadb` |
| ROMs | `/roms` → `$DATA_ROOT/media-stack/games/roms` |
| Komodo stack | `media-games` |
| Route | `https://romm.home.prsgoo.com:8443` (admin-only) |

## Env Variables (stack .env)

```
ROMM_DB_PASSWORD=<value>
ROMM_DB_ROOT_PASSWORD=<value>
ROMM_AUTH_SECRET_KEY=<openssl rand -hex 32>
IGDB_CLIENT_ID=<value>          # from dev.twitch.tv
IGDB_CLIENT_SECRET=<value>      # from dev.twitch.tv
SCREENSCRAPER_USER=<value>      # free account at screenscraper.fr
SCREENSCRAPER_PASSWORD=<value>
STEAMGRIDDB_API_KEY=<value>     # free key at steamgriddb.com
```

`HASHEOUS_API_ENABLED=true` is hardcoded in the compose - no account or key needed.

## Metadata Providers

| Provider | Purpose | Account required |
|----------|---------|-----------------|
| IGDB (Twitch) | Modern games - descriptions, covers, release dates | Yes - dev.twitch.tv |
| ScreenScraper | Retro ROMs - best coverage for classic platforms | Yes - screenscraper.fr (free) |
| SteamGridDB | Custom artwork (grids, heroes, logos, icons) | Yes - steamgriddb.com (free) |
| Hasheous | ROM identification by file hash | No - `HASHEOUS_API_ENABLED=true` |
| RetroAchievements | Achievement tracking for retro games | Yes - retroachievements.org (optional) |

## Key Takeaways

- RomM listens on port 8080 internally; compose maps `3000:8080`
- MariaDB service and container are both named `romm-db`
- `depends_on: condition: service_healthy, restart: true` - RomM auto-restarts if MariaDB restarts
- `start_interval: 10s` in MariaDB healthcheck improves first-boot startup detection
- `HASHEOUS_API_ENABLED=true` is hardcoded in the compose - identifies ROMs by file hash without a key
- File-less game entries are supported from RomM 5.3.1 onwards - create platforms and add games without uploading files (for Steam, Xbox, or physical catalog tracking)
- First boot takes 6-8 minutes: DB initialization + schema migrations + asset path migration
- Renaming the DB service (e.g. `mariadb` → `romm-db`) while data exists: the old container must be manually stopped and removed before the new one starts, otherwise both try to lock the same data files

## Troubleshooting

**DB lock error on startup (`aria_log_control` / `ibdata1` cannot be locked)**

Another MariaDB process is holding a lock on the data directory - usually an old container left running after a service rename or failed redeploy.

```bash
# On the CT, identify and remove the old container
docker ps -a | grep -i maria
docker stop <old-container-name> && docker rm <old-container-name>
docker restart romm-db
```

**RomM shows 502 via Traefik**

RomM may still be running first-boot migrations. Check logs:

```bash
docker logs romm --tail 50
```

Wait for `Application startup complete` before expecting the UI to respond.

**Metadata not fetching**

Verify API keys are set in Settings > Metadata Providers inside the RomM UI. Env vars inject the keys on startup but the UI settings page is the source of truth at runtime.
