---
title: Media Download Services
---

# Media Download Services (CT 302)

LXC: [media dl](../../lxcs/media-dl.md)

| Service | Article | Port |
|---------|---------|------|
| qBittorrent | [qbittorrent](qbittorrent.md) | 8080 |
| SABnzbd | [sabnzbd](sabnzbd.md) | 8085 |

## Hardlinks

CT 302 mounts `$DATA_ROOT/torrents` → `/torrents` and `$DATA_ROOT/usenet` → `/usenet`. CT 300 mounts `$DATA_ROOT/media` → `/media`. All three are on the same host filesystem, so hardlinks between download paths and library paths work - see [media arr](../media-arr/_index.md).
