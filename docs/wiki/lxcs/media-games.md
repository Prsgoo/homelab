---
title: Games LXC (CT 304)
updated: 2026-09-29
---

# Games LXC (CT 304)

RomM game library stack. Manages ROM files and virtual catalog entries for Steam/Xbox (file-less). MariaDB for metadata storage.

## Specs

| Setting | Value |
|---------|-------|
| CT ID | 304 |
| Hostname | games |
| Template | Debian 13 standard |
| rootfs | 8GB |
| RAM | 2048MB |
| Cores | 2 |
| IP | 192.168.50.34 |
| onboot | yes |
| Unprivileged | yes |
| Features | nesting=1, keyctl=1 |

## Bind Mounts

| Mount | Host Path | Container Path |
|-------|-----------|----------------|
| mp0 | `$DATA_ROOT/config/media-games` | `/data` |
| mp1 | `$DATA_ROOT/media-stack/games` | `/library` |

RomM mounts `/library` as `/romm/library` in the container. RomM expects platform folders at `/romm/library/roms/<platform>/`, which maps to `$DATA_ROOT/media-stack/games/roms/<platform>/` on the host.

## UID Scheme

CT 304 uses the 1340–1349 block per the [UID/GID standards](../standards/user-group-scheme.md).

| UID  | User  | Used by | Note |
|------|-------|---------|------|
| 1340 | romm  | RomM    | Reserved; image runs as container root (UID 0), see [exceptions](../standards/service-uid-exceptions.md) |

All users have primary GID 1300 (`media`).

Config dir ownership on host:

| Path | Owner | Mode |
|------|-------|------|
| `$DATA_ROOT/config/media-games/` | `100000:1300` | 750 |
| `$DATA_ROOT/config/media-games/romm/` | `100000:1300` | 750 |
| `$DATA_ROOT/config/media-games/mariadb/` | `100999:100999` | 750 |

MariaDB runs as UID 999 inside the container, which maps to host UID 100999 via idmap.

## idmap

```
lxc.idmap: u 0 100000 1000
lxc.idmap: u 1000 1000 500
lxc.idmap: u 1500 101500 64036
lxc.idmap: g 0 100000 1000
lxc.idmap: g 1000 1000 500
lxc.idmap: g 1500 101500 64036
```

Container UIDs 1000–1499 map 1:1 to host UIDs 1000–1499.

Also requires in `/etc/subuid` and `/etc/subgid` on the Proxmox host:
```
root:1000:500
```

## ACL

FileBrowser (CT 100) runs as container root = host UID 100000. The ACL entry below grants it read/write access to stack files:

```bash
setfacl -Rm u:100000:rwx,d:u:100000:rwx $DATA_ROOT/config/media-games
```

This is set by `ct304-games.sh` and is required for Komodo stack management via FileBrowser.

## Komodo

| Setting | Value |
|---------|-------|
| Server | media-games |
| Address | `wss://192.168.50.34:8120` |
| Root directory | `/data/komodo` |

## Traefik Routes

| Service | Internal URL | Route |
|---------|-------------|-------|
| RomM | `http://192.168.50.34:3000` | `romm.home.prsgoo.com` (admin entrypoint) |

## Services

→ [games services](../services/media-games/_index.md)

## Post-Setup Steps

1. Open RomM at `https://romm.home.prsgoo.com:8443` and create an admin account.
2. Go to Settings > Metadata Providers and configure IGDB, ScreenScraper, and SteamGridDB.
3. Create platforms and add ROMs (with files in `/roms`) or file-less entries for Steam/Xbox games.
