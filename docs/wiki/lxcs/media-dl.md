---
title: Media Download LXC (CT 302)
updated: 2026-08-05
---

# Media Download LXC (CT 302)

Download container. Runs qBittorrent (torrents) and SABnzbd (Usenet) via Docker.

## Specs

| Setting | Value |
|---------|-------|
| CT ID | 302 |
| Hostname | media-dl |
| Template | Debian 13 standard |
| rootfs | 8GB |
| RAM | 1024MB |
| Cores | 2 |
| CPU limit | 2 |
| IP | <media-dl-ip> |
| onboot | yes |
| Unprivileged | yes |
| Features | nesting=1, keyctl=1 |

## Bind Mounts

| Mount | Host Path | Container Path |
|-------|-----------|---------------|
| mp0 | `$DATA_ROOT/config/media-dl` | `/data` |
| mp1 | `$DATA_ROOT/media-stack/torrents` | `/torrents` |
| mp2 | `$DATA_ROOT/media-stack/usenet` | `/usenet` |

mp1 and mp2 share the same host filesystem as CT 300's `/media` mount - hardlinks work between download paths and the media library.

## idmap

```
lxc.idmap: u 0 100000 1000
lxc.idmap: u 1000 1000 500
lxc.idmap: u 1500 101500 64036
lxc.idmap: g 0 100000 1000
lxc.idmap: g 1000 1000 500
lxc.idmap: g 1500 101500 64036
```

## UID/GID Scheme

| UID | Service |
|-----|---------|
| 1320 | qBittorrent |
| 1307 | SABnzbd |

## Komodo

| Setting | Value |
|---------|-------|
| Server | media-dl |
| Address | `wss://<media-dl-ip>:8120` |
| Root directory | `/data/komodo` |

## Services

→ [media dl](../services/media-dl/_index.md) - qBittorrent, SABnzbd
