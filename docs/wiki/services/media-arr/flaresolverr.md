---
title: FlareSolverr
updated: 2026-08-05
---

# FlareSolverr

LXC: [media arr](../../lxcs/media-arr.md) (CT 300) - Cloudflare challenge solver for Prowlarr.

## Instance

| Setting | Value |
|---------|-------|
| Port | 8191 (internal - no Traefik route) |
| Image | `ghcr.io/thephaseless/byparr:latest` (drop-in replacement) |
| Managed as | Komodo stack `media-arr` |

Internal-only: Prowlarr reaches it at `http://flaresolverr:8191` by Docker container name.

DNS override required - the headless browser inside FlareSolverr makes direct requests to indexer domains:

```yaml
dns:
  - 1.1.1.1
  - 8.8.8.8
```
