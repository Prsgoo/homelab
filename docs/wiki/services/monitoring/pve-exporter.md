---
title: pve-exporter
updated: 2026-08-05
---

# pve-exporter

LXC: [monitoring](../../lxcs/monitoring.md) (CT 202) - exports Proxmox VE metrics to Prometheus.

## Instance

| Setting | Value |
|---------|-------|
| Port | 9221 (internal, no Traefik route) |
| Config | `/data/pve-exporter/pve.yml` |
| Managed as | Komodo stack `monitoring` |

## pve.yml Structure

```yaml
default:
  user: pve-exporter@pve
  token_name: metrics
  token_value: <UUID>
  verify_ssl: false
  privsep: false
```

`privsep: false` is required - the default `privsep: true` spawns a privilege separation process that fails in an LXC because it can't set resource limits. Without it, the exporter exits silently.

## PVE Token Setup

Create the token in Proxmox → Datacenter → Permissions → API Tokens:
- User: `pve-exporter@pve` (dedicated PVE user)
- Token ID: `metrics`
- Role: `PVEAuditor` at `/` (datacenter scope)
- Privilege separation: off

## Key Takeaways

- `privsep: false` in pve.yml is mandatory - default is true and silently breaks in LXC
- Token must have `PVEAuditor` at `/` - scoped to a single node misses cluster-level metrics
- Use a dedicated `pve-exporter@pve` user, not the API management token
