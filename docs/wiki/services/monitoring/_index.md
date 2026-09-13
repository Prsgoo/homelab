---
title: Monitoring Services
---

# Monitoring Services (CT 202)

LXC: [monitoring](../../lxcs/monitoring.md)

| Service | Article | Port |
|---------|---------|------|
| Prometheus | [prometheus](prometheus.md) | 9090 |
| Grafana | [grafana](grafana.md) | 3000 |
| Uptime Kuma | [uptime kuma](uptime-kuma.md) | 3001 |
| pve-exporter | [pve exporter](pve-exporter.md) | 9221 (internal) |

## node_exporter Deployment

node_exporter runs on every LXC. Deployment method depends on whether Docker is available.

| LXC | Method | Komodo stack |
|-----|--------|-------------|
| CT 100 management | Docker | `node-exporter-local` |
| CT 200 ultrafeeder | Docker | `node-exporter-ultrafeeder` |
| CT 201 iot | Docker | `node-exporter-iot` |
| CT 202 monitoring | Docker | `node-exporter-monitoring` |
| CT 300 media-arr | Docker | `node-exporter-media-arr` |
| CT 301 media-server | Docker | `node-exporter-media-server` |
| CT 302 media-dl | Docker | `node-exporter-media-dl` |
| CT 101 pihole | Binary systemd service | - |
| CT 400 game-panel | Binary systemd service | - |
| CT 401 minecraft-wings | Binary systemd service | - |

Docker stacks use `network_mode: host` so node_exporter binds to `:9100` on each LXC's own IP.

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
4. Update the scrape target table in [monitoring](../../lxcs/monitoring.md)

## Key Takeaways

- 12 active scrape targets: 10 LXCs (CT 600 not monitored) + pve-exporter + Prometheus self
- pve-exporter uses a dedicated read-only PVEAuditor token
- `prometheus.yml` changes take effect via HTTP reload - no container restart needed
