---
title: Prometheus
updated: 2026-08-05
---

# Prometheus

LXC: [monitoring](../../lxcs/monitoring.md) (CT 202) - metrics collector.

## Instance

| Setting | Value |
|---------|-------|
| Port | 9090 |
| Config | `/data/prometheus.yml` (bind-mounted) |
| URL | `https://prometheus.home.example.com:<admin-port>` |
| Managed as | Komodo stack `monitoring` |

## Scrape Targets

**Job: `prometheus`**
- `localhost:9090` - self

**Job: `pve`**
- `pve-exporter:9221` (metrics_path `/pve`, target param `<proxmox-host-ip>`) - Proxmox host

**Job: `node`** - single job, instance label per target:

| Instance | Target |
|----------|--------|
| `management` | `<mgmt-ip>:9100` |
| `pihole` | `<pihole-ip>:9100` |
| `ultrafeeder` | `<ultrafeeder-ip>:9100` |
| `iot` | `<iot-ip>:9100` |
| `media-arr` | `<media-arr-ip>:9100` |
| `media-server` | `<media-server-ip>:9100` |
| `media-dl` | `<media-dl-ip>:9100` |
| `game-panel` | `<panel-ip>:9100` |
| `minecraft-wings` | `<wings-ip>:9100` |
| `monitoring` | `<monitoring-ip>:9100` |

CT 600 is not present - no node-exporter installed.

**Job: `ultrafeeder`**
- `<ultrafeeder-ip>:9273` - ADS-B stats (requires `:telegraf` image tag)
- `<ultrafeeder-ip>:9274` - feed stats

## Config Reload

```bash
curl -X POST http://<monitoring-ip>:9090/-/reload
```

## Editing prometheus.yml

Edit in-place only - editors that do atomic rename-based saves (write to temp file, then rename) replace the file's inode; the running Prometheus container stays bound to the old one and silently keeps serving the previous config.
