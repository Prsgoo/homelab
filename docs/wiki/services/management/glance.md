---
title: Glance
updated: 2026-08-05
---

# Glance

LXC: [management lxc](../../lxcs/management-lxc.md) (CT 100) - homelab dashboard.

## Instance

| Setting | Value |
|---------|-------|
| Port | 8081 |
| Config | `/data/config/management/glance/config/glance.yml` |
| Local repo copy | `stacks/management/glance/glance.yml` |
| URL | `https://glance.home.example.com` |
| Managed as | Komodo stack `glance` |

Glance hot-reloads on config change - no container restart needed. Env var changes (`PVE_API_TOKEN`) require a restart.
