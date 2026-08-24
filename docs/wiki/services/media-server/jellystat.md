---
title: Jellystat
updated: 2026-08-05
---

# Jellystat

LXC: [media server](../../lxcs/media-server.md) (CT 301) - Jellyfin watch history and stats dashboard.

## Instance

| Setting | Value |
|---------|-------|
| Port | 3000 |
| Database | Named Docker volume `jellystat-db` (PostgreSQL) |
| UID/GID | 1311:1311 (reserved; DB in named volume, not bind-mounted) |
| URL | `https://jellystat.home.example.com:<admin-port>` |
| Managed as | Komodo stack `media-server` |

## Jellyfin Connection

- URL: `http://<media-server-ip>:8096`
- API key: configured in Jellystat → Settings

## Data Persistence Note

Jellystat's database is in a named Docker volume (`jellystat-db`), not a bind mount. It survives container restarts but **not** CT 301 rootfs recreation. Back up the volume if historical stats matter:

```bash
docker exec jellystat-db pg_dump -U jellystat jellystat > jellystat-backup.sql
```
