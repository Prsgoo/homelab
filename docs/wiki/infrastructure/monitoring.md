---
title: Monitoring
updated: 2026-08-05
---

# Monitoring

Homelab metrics + uptime stack. See [monitoring](../lxcs/monitoring.md) for CT 202 specs and setup details.

## Stack

| Component | Role |
|-----------|------|
| Prometheus | Time-series metrics collection |
| Grafana | Dashboards and visualization (long-term metrics) |
| pve-exporter | Proxmox host metrics via API |
| node_exporter | Per-container OS metrics (CPU, RAM, disk, network) |
| Uptime Kuma | Lightweight service uptime checks + push notifications (internal-only, no third-party pings) |

## node_exporter Deployment

| LXC | Method | Managed by |
|-----|--------|-----------|
| CT 100 management | Docker (Komodo stack `node-exporter-local`) | Komodo |
| CT 200 ultrafeeder | Docker (Komodo stack `node-exporter-ultrafeeder`) | Komodo |
| CT 201 iot | Docker (Komodo stack `node-exporter-iot`) | Komodo |
| CT 202 monitoring | Docker (Komodo stack `node-exporter-monitoring`) | Komodo |
| CT 300 media-arr | Docker (Komodo stack `node-exporter-media-arr`) | Komodo |
| CT 301 media-server | Docker (Komodo stack `node-exporter-media-server`) | Komodo |
| CT 302 media-dl | Docker (Komodo stack `node-exporter-media-dl`) | Komodo |
| CT 101 pihole | Binary systemd service | systemd |
| CT 400 game-panel | Binary systemd service | systemd |
| CT 401 minecraft-wings | Binary systemd service | systemd |

Docker stacks use `network_mode: host` - node_exporter binds to :9100 on the LXC's IP.

Binary installs: `/usr/local/bin/node_exporter`, user `node_exporter`, service at `/etc/systemd/system/node_exporter.service`.

## Dashboards

| Dashboard | Grafana ID | What it shows |
|-----------|-----------|---------------|
| Node Exporter Full | 1860 | Per-container CPU, RAM, disk, network |
| Proxmox via Prometheus | 10347 | Proxmox host node, VMs, storage |

## Adding a New LXC

1. If Docker LXC: create a `node-exporter-<name>` Komodo stack using `stacks/node-exporter/compose.yaml`
2. If native LXC: install the node_exporter binary and systemd service (see CT 101 pattern)
3. Add a scrape target to `/data/prometheus.yml` on CT 202 and reload: `curl -X POST http://localhost:9090/-/reload`
4. Update the scrape target table in [monitoring](../lxcs/monitoring.md)

## Key Takeaways

- 12 active targets: 10 LXCs (CT 600 not monitored) + pve-exporter + Prometheus self
- pve-exporter uses `pve-exporter@pve!metrics` token - dedicated read-only user with PVEAuditor role at `/`
- prometheus.yml changes take effect via HTTP reload - no container restart needed
