---
title: Unbound
updated: 2026-08-05
---

# Unbound

LXC: [pihole](../../lxcs/pihole.md) (CT 101) - recursive DNS resolver and internal domain handler.

## Instance

| Setting | Value |
|---------|-------|
| Port | `5335` (localhost only) |
| Config dir | `/etc/unbound/unbound.conf.d/` |

Pi-hole uses `127.0.0.1#5335` as its upstream. Unbound listens only on localhost.

## Config Files

| File | Purpose |
|------|---------|
| `home-internal.conf` | Redirect zone - resolves all `*.home.example.com` to `<mgmt-ip>` |
| `homelab.conf` | Performance tuning only (legacy name, no zone entries) |
| `z-performance.conf` | Additional performance tuning - must sort after `pi-hole.conf` alphabetically |

Files are processed in alphabetical order by Unbound. `z-performance.conf` must start with `z-` to load after Pi-hole's auto-generated `pi-hole.conf`.

## Redirect Zone (`home-internal.conf`)

```conf
server:
  local-zone: "home.example.com." redirect
  local-data: "home.example.com. A <mgmt-ip>"
```

This makes every `*.home.example.com` query return `<mgmt-ip>` (Traefik). Traefik handles SNI routing to the correct backend.

## Verify

```bash
dig home.example.com @<pihole-ip>
# Expected: <mgmt-ip>
```

## Known Non-Issue

Pi-hole v6 + Unbound produces TCP connection errors in the Pi-hole log (`connection refused 127.0.0.1:5335 (TCP)`). These are noise - Unbound is running and responding correctly on UDP. Pi-hole v6 probes TCP unconditionally.
