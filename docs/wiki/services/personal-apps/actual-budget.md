---
title: Actual Budget
updated: 2026-08-05
---

# Actual Budget

LXC: [personal apps](../../lxcs/personal-apps.md) (CT 600) - self-hosted personal finance app.

## Instance

| Setting | Value |
|---------|-------|
| Port | 5006 |
| Config | `/data/actual-budget/` |
| UID/GID | `1001:1001` (hardcoded in image) |
| URL | `https://budget.home.example.com:<admin-port>` |
| Managed as | Komodo stack `personal-apps` (if Periphery is installed) |

The Actual Budget image runs as UID 1001 and cannot be changed via `PUID`/`PGID`. The config directory must be pre-owned `1001:1001` inside the LXC (host-side: `101001:101001` due to idmap).

## Access

Admin-only via `admin-only` Traefik middleware - requires being on the `tag:admin` Tailscale ACL. Built-in password auth is configured inside the app.
