---
title: Tailscale
updated: 2026-08-05
---

# Tailscale

Tailscale provides remote access to the homelab from anywhere. Two LXCs have Tailscale installed with distinct roles.

## Architecture

```
Phone (Tailscale)
  → Pi-hole CT 101 (<pihole-ts-ip>) - DNS server
  → CT 100 subnet router (<mgmt-ts-ip>) - routes <your-ip-range>
      → any LAN IP (ACLs restrict to Traefik :80/:443 on .100)
```

- **CT 101** is the global nameserver for the Tailscale network - all DNS queries from Tailscale clients go through Pi-hole
- **CT 100** is the subnet router - advertises the full `<your-ip-range>`, ACLs restrict access to port 80/443 on <mgmt-ip> only

## Tailscale Node IPs

| LXC | CT | Tailscale IP | Role |
|-----|----|--------------|------|
| pihole | 101 | <pihole-ts-ip> | DNS server |
| management | 100 | <mgmt-ts-ip> | Subnet router (<mgmt-ip>/32) |
| game-panel | 400 | <panel-ts-ip> | Direct access |
| minecraft-wings | 401 | <wings-ts-ip> | Direct access |

## TUN Device Setup (all LXCs)

Always use `dev0` - do NOT use the cgroup2/mount.entry method (breaks on cgroupv2):

```bash
pct stop <vmid>
# Remove any bad entries if the helper script added them:
sed -i '/lxc.cgroup2.devices.allow: c 10:200/d' /etc/pve/lxc/<vmid>.conf
sed -i '/lxc.mount.entry: \/dev\/net\/tun/d' /etc/pve/lxc/<vmid>.conf
echo 'dev0: /dev/net/tun,gid=0,uid=0' >> /etc/pve/lxc/<vmid>.conf
pct start <vmid>
```

## Install Method

Use the community-scripts helper - always enter the CT ID when prompted:
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/addon/add-tailscale-lxc.sh)
```
Run the TUN cleanup above after the script finishes.

## Tailscale Up Flags

| LXC | Command |
|-----|---------|
| CT 101 (DNS) | `tailscale up --accept-routes=false --accept-dns=false` |
| CT 100 (subnet router) | `tailscale up --advertise-routes=<your-ip-range> --accept-dns=false --accept-routes=false` |
| CT 400/401 (direct) | `tailscale up --accept-routes=false --accept-dns=false` |

Always use `--accept-dns=false` inside LXCs - otherwise Tailscale's DNS takes over and breaks local service connections.

## Pi-hole DNS Config

Pi-hole must use `listeningMode = "ALL"` to accept queries from Tailscale clients (100.x.x.x range):

`/etc/pihole/pihole.toml`:
```toml
listeningMode = "ALL"
```

Tailscale admin DNS settings:
- Global nameserver: `<pihole-ts-ip>`
- Override local DNS: enabled
- MagicDNS: enabled

## Tags

Tag-based permissions allow scoped access per device. Only you (the owner) can assign tags from the Tailscale admin Machines page. See [management lxc](../lxcs/management-lxc.md) for the full design and the per-service `ipAllowList` layer that works alongside this ACL.

| Tag | Who | Access |
|-----|-----|--------|
| `tag:admin` | Your own devices | Full LAN subnet + all Tailscale nodes + Traefik admin <admin-port> |
| `tag:streaming` | Streaming devices (TV, phone, etc.) | Traefik 80/443, restricted by `ipAllowList` to Jellyfin + Seerr only |
| `tag:minecraft` | Player devices | Wings (<wings-ts-ip>) direct + Traefik 80/443, restricted by `ipAllowList` to game-panel only |
| *(untagged)* | Any Tailscale node | Nothing - no grant applies |

There is no general "everyone" grant anymore - every non-admin tag's reach into Traefik is scoped down further by Traefik's own `ipAllowList` middleware per router (see [management lxc](../lxcs/management-lxc.md)), since Tailscale ACLs can't distinguish between services sharing the same port.

## Access Control (ACLs)

Configured at tailscale.com/admin/acls.

```json
{
  "tagOwners": {
    "tag:admin":     ["autogroup:owner"],
    "tag:streaming": ["autogroup:owner"],
    "tag:minecraft": ["autogroup:owner"]
  },
  "grants": [
    {"src": ["tag:admin"], "dst": ["100.64.0.0/10", "<your-ip-range>"], "ip": ["*"]},
    {"src": ["tag:minecraft"], "dst": ["<wings-ts-ip>"], "ip": ["*"]},
    {"src": ["tag:admin", "tag:streaming", "tag:minecraft"], "dst": ["<mgmt-ip>"], "ip": ["tcp:80", "tcp:443"]},
    {"src": ["*"], "dst": ["<pihole-ts-ip>"], "ip": ["udp:53", "tcp:53"]}
  ]
}
```

- `tag:admin`: full access to all Tailscale IPs, full LAN subnet, and Traefik admin <admin-port>
- `tag:minecraft`: direct access to Wings (CT 401, the actual game connection) + Traefik 80/443 (further narrowed to game-panel only by Traefik's `minecraft-shared` middleware)
- `tag:streaming`: Traefik 80/443 only (narrowed to Jellyfin + Seerr by Traefik's `streaming-shared` middleware)
- Everyone, including untagged: DNS to Pi-hole (`<pihole-ts-ip>:53`) - required because "Override local DNS" is tailnet-wide, not per-tag; without this, any non-admin device's general internet DNS breaks the moment it connects (see [management lxc](../lxcs/management-lxc.md))
- Untagged: nothing beyond DNS - no grant to any LAN/Traefik destination

## Key Takeaways

- Advertise `<your-ip-range>` - ACLs are the security layer, not the route scope
- ACLs enforce port-level access - iptables inside the LXC does not work (Tailscale's `ts-input` chain intercepts first)
- `listeningMode = "ALL"` is required on Pi-hole - default `LOCAL` rejects 100.x.x.x queries
- Admin services only exist on Traefik <admin-port>, and only `tag:admin` has a grant reaching that port at all - no other tag should ever be added to it, since the port hosts every admin tool with no further per-service distinction possible at the ACL level
- This ACL only controls *remote* (Tailscale) access - it has no effect on a device physically on the home network. LAN segmentation is a separate initiative.
- Adding a new service: decide tier first (admin-only → `admin` entrypoint at 8443 + `admin-only` middleware; shared with a specific tag → `web`/`websecure` + a dedicated `ipAllowList` middleware); see [management lxc](../lxcs/management-lxc.md)
