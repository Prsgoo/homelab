---
title: Pi-hole
updated: 2026-08-05
---

# Pi-hole

LXC: [pihole](../../lxcs/pihole.md) (CT 101) - DNS sinkhole and internal resolver for the LAN and Tailscale network.

## Instance

| Setting | Value |
|---------|-------|
| Admin UI | `http://<pihole-ip>/admin` (Traefik: `https://pihole.home.example.com:<admin-port>`) |
| Listening mode | All Interfaces |
| Upstream DNS | `127.0.0.1#5335` (Unbound, local) |
| Config | `/etc/pihole/` (in rootfs) |

Listening mode must be "All Interfaces" - "Allow only local requests" blocks queries arriving over Tailscale (100.x.x.x), since that subnet is not in Pi-hole's local-network definition.

## DNS Architecture

```
Client → Pi-hole (CT 101, :53) → Unbound (CT 101, :5335) → Root nameservers
                ↓ (local names)
         Unbound redirect zone → <mgmt-ip> (Traefik)
```

All `*.home.example.com` queries resolve to `<mgmt-ip>` (Traefik) via an Unbound redirect zone. See [unbound](unbound.md).

## Blocklists

| List | Purpose |
|------|---------|
| StevenBlack unified | General ad/tracking blocking |
| HaGeZi Multi PRO | Aggressive ad/tracker list |
| Custom IoT blocklist | IoT device phone-home blocking |

## Router Configuration

DHCP settings on the router:
- DNS Server 1: `<pihole-ip>`
- DNS Server 2: *(empty)* - no fallback so outages are visible, not silently bypassed

## Tailscale DNS

In the Tailscale admin console, set the global nameserver to `<pihole-ts-ip>` (CT 101 Tailscale IP). This routes all Tailscale client DNS through Pi-hole, making `*.home.example.com` resolve over VPN.

## Key Takeaways

- Pi-hole v6 API auth uses `password:` in Glance, not the old token format
- Never set a DNS fallback on the router - if Pi-hole is down, breakage surfaces immediately instead of silently bypassing blocks
- Tailscale nameserver must be the Tailscale IP (<pihole-ts-ip>), not the LAN IP (<pihole-ip>), to work from remote devices
