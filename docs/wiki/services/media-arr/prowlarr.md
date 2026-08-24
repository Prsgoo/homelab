---
title: Prowlarr
updated: 2026-08-05
---

# Prowlarr

LXC: [media arr](../../lxcs/media-arr.md) (CT 300) - indexer manager and proxy for Sonarr/Radarr.

## Instance

| Setting | Value |
|---------|-------|
| Port | 9696 |
| Config | `/data/prowlarr/` |
| UID/GID | 1302:1302 |
| URL | `https://prowlarr.home.example.com:<admin-port>` |
| Managed as | Komodo stack `media-arr` |

## DNS Override

```yaml
dns:
  - 1.1.1.1
  - 8.8.8.8
```

Required in compose - Prowlarr must reach public indexers directly, bypassing Pi-hole (which blocks tracker domains).

## FlareSolverr Integration

`http://flaresolverr:8191` - registered in Prowlarr under Settings → Indexers → Add FlareSolverr. Enables scraping of Cloudflare-protected indexers.
