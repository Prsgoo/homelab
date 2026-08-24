---
title: Pi-hole LXC (CT 101)
updated: 2026-08-05
---

# Pi-hole LXC (CT 101)

DNS server. Runs Pi-hole and Unbound directly in the LXC (no Docker).

## Specs

| Setting | Value |
|---------|-------|
| CT ID | 101 |
| Hostname | pihole |
| Template | Debian 13 standard |
| rootfs | 4GB |
| RAM | 1024MB |
| Cores | 4 |
| CPU units | 2048 |
| IP | <pihole-ip> |
| onboot | yes |
| Unprivileged | yes |
| Features | nesting=1 |

## Bind Mounts

None - Pi-hole and Unbound store config in rootfs (`/etc/pihole/`, `/etc/unbound/`). Small and easily recreatable.

## idmap

Not required - Pi-hole and Unbound run as root/service users within the LXC.

## Komodo

Binary Periphery agent only (no Docker stacks on this LXC).

| Setting | Value |
|---------|-------|
| Server | pihole |
| Address | `wss://<pihole-ip>:8120` |

## Tailscale

DNS server for all Tailscale clients.

| Setting | Value |
|---------|-------|
| Tailscale IP | <pihole-ts-ip> |
| Flags | `--accept-routes=false --accept-dns=false` |

TUN device entry in `/etc/pve/lxc/101.conf`:
```
dev0: /dev/net/tun,gid=0,uid=0
```

See [tailscale](../infrastructure/tailscale.md).

## Services

→ [pihole](../services/pihole/_index.md) - Pi-hole, Unbound
