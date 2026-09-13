---
title: Monitoring
updated: 2026-09-13
---

# Monitoring

Homelab-wide metrics and uptime stack running on CT 202.

| Component | Role |
|-----------|------|
| Prometheus | Time-series metrics collection |
| Grafana | Dashboards and visualization |
| pve-exporter | Proxmox host metrics via API |
| node_exporter | Per-container OS metrics (CPU, RAM, disk, network) - runs on every LXC |
| Uptime Kuma | Service uptime checks and push notifications (internal-only) |

For service configuration, deployment details, and operational procedures see [monitoring services](../services/monitoring/_index.md).
