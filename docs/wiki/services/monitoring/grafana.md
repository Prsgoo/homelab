---
title: Grafana
updated: 2026-08-05
---

# Grafana

LXC: [monitoring](../../lxcs/monitoring.md) (CT 202) - metrics visualization.

## Instance

| Setting | Value |
|---------|-------|
| Port | 3000 |
| Config | `/data/grafana/` |
| UID/GID | `100472:100472` (host-side bind mount ownership) |
| URL | `https://grafana.home.example.com:<admin-port>` |
| Managed as | Komodo stack `monitoring` |

The bind-mount directory must be pre-owned `100472:100472` - Grafana refuses to start if it can't write its database. Because CT 202 uses an idmap, host UID 100472 maps to container UID 472 (the Grafana user inside the container).

## Dashboards

| ID | Name | Source |
|----|------|--------|
| 1860 | Node Exporter Full | Grafana.com |
| 10347 | Proxmox via pve-exporter | Grafana.com |
| 18398 | Ultrafeeder ADS-B | Grafana.com |

## Key Setting

`GF_PANELS_DISABLE_SANITIZE_HTML=true` - required for some dashboard panels (Ultrafeeder stat panels use raw HTML). Set via compose environment, not grafana.ini.
