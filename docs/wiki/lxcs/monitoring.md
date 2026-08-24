---
title: Monitoring LXC (CT 202)
updated: 2026-08-05
---

# Monitoring LXC (CT 202)

Metrics and uptime monitoring. Runs Prometheus, Grafana, Uptime Kuma, and pve-exporter via Docker.

## Specs

| Setting | Value |
|---------|-------|
| CT ID | 202 |
| Hostname | monitoring |
| Template | Debian 13 standard |
| rootfs | 8GB |
| RAM | 1024MB |
| Cores | 2 |
| IP | <monitoring-ip> |
| onboot | yes |
| Unprivileged | yes |
| Features | nesting=1, keyctl=1 |

## Bind Mounts

| Mount | Host Path | Container Path |
|-------|-----------|---------------|
| mp0 | `$DATA_ROOT/config/monitoring` | `/data` |

## idmap

```
lxc.idmap: u 0 100000 1000
lxc.idmap: u 1000 1000 500
lxc.idmap: u 1500 101500 64036
lxc.idmap: g 0 100000 1000
lxc.idmap: g 1000 1000 500
lxc.idmap: g 1500 101500 64036
```

Container UIDs 1000–1499 map 1:1 to host UIDs 1000–1499.

## Bind Mount Ownership

Grafana runs as UID 472 inside its container. With idmap, this maps to host UID 100472. Pre-create and own the Grafana data directory:

```bash
chown -R 100472:100472 $DATA_ROOT/config/monitoring/grafana/
```

Prometheus and Uptime Kuma run as root in their containers - no special ownership needed.

## Komodo

| Setting | Value |
|---------|-------|
| Server | monitoring |
| Address | `wss://<monitoring-ip>:8120` |
| Root directory | `/data/komodo` |

## Services

→ [monitoring](../services/monitoring/_index.md) - Prometheus, Grafana, Uptime Kuma, pve-exporter
