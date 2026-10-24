---
title: WARP Proxy
updated: 2026-10-24
---

# WARP Proxy

LXC: [management lxc](../../lxcs/management-lxc.md) (CT 100) - Cloudflare WARP SOCKS5 proxy for bypassing ISP-level IP blocks.

## Why

Some sites are blocked at the IP level by ISPs under court orders. DNS resolves correctly but TCP connections to the destination IPs are null-routed at the ISP backbone. WARP routes outbound traffic through Cloudflare's network, bypassing the block without a paid VPN.

## Instance

| Setting | Value |
|---------|-------|
| Stack path | `/data/config/management/komodo/periphery/stacks/warp-proxy/compose.yaml` |
| SOCKS5 endpoint | `<server-ip>:1080` (LAN only, no Traefik route) |
| Managed as | Komodo stack `warp-proxy` |
| Data | Docker volume `warp-data` (WARP account registration) |

## Connecting services

Configure the target service's proxy settings to use:

- **Type:** SOCKS5
- **Host:** `<server-ip>`
- **Port:** `1080`

### Suwayomi

Admin → Settings → Network → Proxy:

| Field | Value |
|-------|-------|
| Type | SOCKS5 |
| Host | `<server-ip>` |
| Port | `1080` |

## Notes

- WARP registers its own Cloudflare account on first start — no account or license required
- Uses WARP proxy mode (not full tunnel): no NET_ADMIN or /dev/net/tun needed
- No kill switch configured: if WARP drops, traffic falls back to direct connection (which will be ISP-blocked for affected sites)
- Port 1080 is bound to the management LXC IP only — not reachable from outside the LAN
