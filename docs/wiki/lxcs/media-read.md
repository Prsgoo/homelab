---
title: Media Read LXC (CT 303)
updated: 2026-09-29
---

# Media Read LXC (CT 303)

Manga reading stack. Suwayomi downloads and serves manga; Komga organizes the library and provides OPDS; Komf enriches metadata from AniList/MangaUpdates.

## Specs

| Setting | Value |
|---------|-------|
| CT ID | 303 |
| Hostname | media-read |
| Template | Debian 13 standard |
| rootfs | 8GB |
| RAM | 2048MB |
| Cores | 2 |
| IP | <server-ip> |
| onboot | yes |
| Unprivileged | yes |
| Features | nesting=1, keyctl=1 |

## Bind Mounts

| Mount | Host Path | Container Path |
|-------|-----------|----------------|
| mp0 | `$DATA_ROOT/config/media-read` | `/data` |
| mp1 | `$DATA_ROOT/media-stack/media/library/manga` | `/manga` |

Suwayomi downloads CBZ files to `/manga`. Komga scans `/manga` as a read-only library.

## UID Scheme

CT 303 uses the 1330–1339 block per the [UID/GID standards](../standards/user-group-scheme.md).

| UID  | User      | Used by   | Note |
|------|-----------|-----------|------|
| 1330 | suwayomi  | Suwayomi  | Reserved; image hardcodes UID 1000, see [exceptions](../standards/service-uid-exceptions.md) |
| 1331 | komga     | Komga     | `user: "1331:1300"` in compose |
| 1332 | komf      | Komf      | `user: "1332:1300"` in compose |

All users have primary GID 1300 (`media`).

Config dir ownership on host:

| Path | Owner | Mode |
|------|-------|------|
| `$DATA_ROOT/config/media-read/` | `100000:1300` | 750 |
| `$DATA_ROOT/config/media-read/suwayomi/` | `1000:1300` | 750 |
| `$DATA_ROOT/config/media-read/komga/` | `1331:1300` | 750 |
| `$DATA_ROOT/config/media-read/komf/` | `1332:1300` | 750 |

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

## Komodo

| Setting | Value |
|---------|-------|
| Server | media-read |
| Address | `wss://<server-ip>:8120` |
| Root directory | `/data/komodo` |

## Traefik Routes

| Service | Internal URL | Route |
|---------|-------------|-------|
| Suwayomi | `http://<server-ip>:4567` | `manga-reader.home.<your-domain>` |
| Komga | `http://<server-ip>:25600` | `komga.home.<your-domain>` |

Komf is internal only (connects to Komga via Docker network).

## Services

→ [media-read services](../services/media-read/_index.md) - Suwayomi, Komga, Komf

## Post-Setup Steps

1. Open Komga, create an admin account.
2. Add `/manga` as a library in Komga.
3. Open Suwayomi, install a source extension, configure download path to `/manga` in Settings > Downloads.
4. Komf connects automatically using `KOMGA_USER`/`KOMGA_PASSWORD` env vars in compose `.env`.
