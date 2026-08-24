---
title: SABnzbd
updated: 2026-08-05
---

# SABnzbd

LXC: [media dl](../../lxcs/media-dl.md) (CT 302) - Usenet downloader.

## Instance

| Setting | Value |
|---------|-------|
| Port | 8085 |
| Config | `/data/sabnzbd/` |
| UID/GID | 1307:1307 |
| URL | `https://sabnzbd.home.example.com:<admin-port>` |
| Managed as | Komodo stack `media-dl` |

## News Server

| Setting | Value |
|---------|-------|
| Host | `news.eweka.nl` |
| Port | 563 (SSL) |
| Connections | 30 |

## Download Paths

| Type | Path |
|------|------|
| Temporary (incomplete) | `/usenet/incomplete/` |
| Completed | `/usenet/complete/` |

## Categories

| Category | Final Path |
|----------|-----------|
| `tv` | `/usenet/complete/tv/` |
| `movies` | `/usenet/complete/movies/` |

## Key Settings

- **Hostname whitelist**: must include `sabnzbd.home.example.com` - without it SABnzbd returns "Access denied"
- **External access**: set to "Allow all interfaces" - required to accept connections from Tailscale (100.x.x.x) addresses
- **Par2 threads**: `-t4` for parallel verification

## DNS Override

```yaml
dns:
  - 1.1.1.1
  - 8.8.8.8
```

Same reason as qBittorrent - Pi-hole may block Usenet indexer domains.
