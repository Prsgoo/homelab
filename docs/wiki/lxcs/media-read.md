---
title: Media Read LXC (CT 303)
updated: 2026-09-29
---

# Media Read LXC (CT 303)

Manga stack. Suwayomi downloads from online sources and serves manga via OPDS. Downloaded CBZ files land on the shared media pool where Grimmory (CT 600) can also read them.

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

Suwayomi downloads CBZ files to `/manga`. This is the same physical path as `/library/manga` in CT 600.

## UID Scheme

CT 303 uses the 1330–1339 block per the [UID/GID standards](../standards/user-group-scheme.md).

| UID  | User      | Used by   | Note |
|------|-----------|-----------|------|
| 1330 | suwayomi  | Suwayomi  | Reserved; image hardcodes UID 1000, see [exceptions](../standards/service-uid-exceptions.md) |
| 1331 | komga     | (reserved) | Unused - kept for UID normalization |
| 1332 | komf      | (reserved) | Unused - kept for UID normalization |

All users have primary GID 1300 (`media`).

Config dir ownership on host:

| Path | Owner | Mode |
|------|-------|------|
| `$DATA_ROOT/config/media-read/` | `100000:1300` | 750 |
| `$DATA_ROOT/config/media-read/suwayomi/` | `1000:1300` | 750 |

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
| Suwayomi | `http://<server-ip>:4567` | `manga-reader.home.<your-domain>` (admin entrypoint) |

## Services

→ [media-read services](../services/media-read/_index.md)

## Post-Setup Steps

1. Open Suwayomi, install source extensions (e.g. MangaDex, Weeb Central).
2. Go to Settings > Downloads, set download path to `/manga`.
3. Connect a reading app using the Suwayomi source plugin pointed at `https://manga-reader.home.<your-domain>:8443`.
