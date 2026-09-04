---
title: Media Arr LXC (CT 300)
updated: 2026-09-04
---

# Media Arr LXC (CT 300)

*arr management stack - indexing, downloading, post-processing, subtitles, requests, and IPTV.

## Specs

| Setting | Value |
|---------|-------|
| CT ID | 300 |
| Hostname | media-arr |
| Template | Debian 13 standard |
| rootfs | 32GB |
| RAM | 4096MB |
| Swap | 2048MB |
| Cores | 4 |
| CPU limit | 2 |
| IP | <media-arr-ip> |
| onboot | yes |
| Unprivileged | yes |
| Features | nesting=1, keyctl=1 |

32GB rootfs - Dispatcharr's AIO image alone is ~3.9GB and the full stack (~9 images) fills fast. Update services one at a time to avoid running out of space (see [media arr](../services/media-arr/_index.md)).

## Bind Mounts

| Mount | Host Path | Container Path |
|-------|-----------|---------------|
| mp0 | `$DATA_ROOT/config/media-arr` | `/data` |
| mp1 | `$DATA_ROOT/media-stack/media` | `/media` |
| mp2 | `$DATA_ROOT/media-stack/torrents` | `/torrents` |
| mp3 | `$DATA_ROOT/media-stack/usenet` | `/usenet` |

mp2 and mp3 share the same host filesystem as CT 302's download paths - hardlinks work between them.

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

## UID/GID Scheme

| UID | Service | Note |
|-----|---------|------|
| 1300 | Sonarr | |
| 1301 | Radarr | |
| 1302 | Prowlarr | |
| 1303 | Bazarr | |
| 1304 | Seerr | Reserved - image runs as UID 1000 (node), ignores PUID |
| 1305 | Unpackerr | |
| 1306 | Recyclarr | |
| 1307 | SABnzbd | (used by CT 302 for cross-LXC consistency) |
| 1308 | Dispatcharr | Reserved - AIO image runs as root, ignores PUID |

## Komodo

| Setting | Value |
|---------|-------|
| Server | media-arr |
| Address | `wss://<media-arr-ip>:8120` |
| Root directory | `/data/komodo` |

## Services

→ [media arr](../services/media-arr/_index.md) - Sonarr, Radarr, Prowlarr, Bazarr, Seerr, Dispatcharr, Recyclarr, Unpackerr, FlareSolverr
