---
title: Glance
updated: 2026-09-14
---

# Glance

LXC: [management lxc](../../lxcs/management-lxc.md) (CT 100) - homelab dashboard.

## Instance

| Setting | Value |
|---------|-------|
| Port | 8081 |
| Config | `/data/config/management/glance/config/glance.yml` |
| Local repo copy | `stacks/management/glance/glance.yml` |
| URL | `https://glance.<your-domain>:8443` |
| Managed as | Komodo stack `glance` |

## Environment variables

| Variable | Description |
|----------|-------------|
| `PVE_API_TOKEN` | Proxmox API token for host stats and LXC list |
| `PIHOLE_PASSWORD` | Pi-hole web password for DNS stats widget |
| `WEATHER_LOCATION` | City for weather widget, e.g. `City, Country` |

Glance hot-reloads on config change - no container restart needed. Env var changes require a restart.
