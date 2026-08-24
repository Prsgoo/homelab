---
title: Media Server LXC (CT 301)
updated: 2026-08-05
---

# Media Server LXC (CT 301)

Media server. Runs Jellyfin and Jellystat via Docker.

## Specs

| Setting | Value |
|---------|-------|
| CT ID | 301 |
| Hostname | media-server |
| Template | Debian 13 standard |
| rootfs | 8GB |
| RAM | 4096MB |
| Cores | 4 |
| CPU limit | 3 |
| IP | <media-server-ip> |
| onboot | yes |
| Unprivileged | yes |
| Features | nesting=1, keyctl=1 |

## Bind Mounts

| Mount | Host Path | Container Path | Note |
|-------|-----------|---------------|------|
| mp0 | `$DATA_ROOT/config/media-server` | `/data` | Service configs + Komodo root |
| mp1 | `$DATA_ROOT/media-stack/media` | `/media` | Media library (read-only) |

Media mount is read-only - Jellyfin cannot modify library files.

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

| UID | Service | Note |
|-----|---------|------|
| 1310 | Jellyfin | |
| 1311 | Jellystat | Reserved; Jellystat uses a named Docker volume, not bind mount |

## Komodo

| Setting | Value |
|---------|-------|
| Server | media-server |
| Address | `wss://<media-server-ip>:8120` |
| Root directory | `/data/komodo` |

## Services

→ [media server](../services/media-server/_index.md) - Jellyfin, Jellystat
