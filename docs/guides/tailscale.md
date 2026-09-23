# Remote Access - Tailscale

## What you'll end up with

Full LAN access from any of your devices, anywhere, without opening a single router port. CT 100 advertises `<your-ip-range>` as a Tailscale subnet route. CT 101 (Pi-hole) is the Tailscale DNS nameserver, so `*.home.example.com` resolves correctly on remote devices. Access is controlled per-device via Tailscale ACL tags.

---

## Prerequisites

- CT 100 (management) running with TUN device passthrough configured
- CT 101 (Pi-hole) running with TUN device passthrough configured
- A Tailscale account

---

## 1. Install on CT 101 (Pi-hole - DNS role)

The Tailscale installer for LXC containers is a community helper script:

```bash
pct exec 101 -- bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/addon/add-tailscale-lxc.sh)
```

**Clean up bad TUN entries** added by the script (these don't work correctly on cgroupv2):

```bash
pct stop 101
sed -i '/lxc.cgroup2.devices.allow: c 10:200/d' /etc/pve/lxc/101.conf
sed -i '/lxc.mount.entry: \/dev\/net\/tun/d' /etc/pve/lxc/101.conf
pct start 101
```

Confirm the correct `dev0` entry is there (added by the CT script earlier):

```bash
grep 'dev/net/tun' /etc/pve/lxc/101.conf
# Expected: dev0: /dev/net/tun,gid=0,uid=0
```

**Bring Tailscale up:**

```bash
pct exec 101 -- tailscale up --accept-routes=false --accept-dns=false
```

Follow the authentication URL that appears. After auth, note the Tailscale IP assigned to CT 101 in the [Tailscale admin console](https://login.tailscale.com/admin/machines) - you'll need it for DNS config.

!!! warning "`--accept-dns=false` is required inside LXCs"
    Without this flag, Tailscale overwrites the LXC's `/etc/resolv.conf` with Tailscale DNS, which breaks local service resolution. Always use `--accept-dns=false` on LXC nodes.

---

## 2. Configure Pi-hole as Tailscale DNS

In the [Tailscale admin DNS settings](https://login.tailscale.com/admin/dns):

- **Global nameserver**: enter CT 101's **Tailscale IP** (the `100.x.x.x` address, not `<pihole-ip>`)
- **Override local DNS**: enable
- **MagicDNS**: enable

This routes all DNS queries from Tailscale clients through Pi-hole, making `*.home.example.com` resolve correctly from anywhere on your tailnet.

---

## 3. Install on CT 100 (management - subnet router)

Same process:

```bash
pct exec 100 -- bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/addon/add-tailscale-lxc.sh)
```

Clean up bad TUN entries:

```bash
pct stop 100
sed -i '/lxc.cgroup2.devices.allow: c 10:200/d' /etc/pve/lxc/100.conf
sed -i '/lxc.mount.entry: \/dev\/net\/tun/d' /etc/pve/lxc/100.conf
pct start 100
```

**Bring up as subnet router:**

```bash
pct exec 100 -- tailscale up \
  --advertise-routes=<your-ip-range> \
  --accept-dns=false \
  --accept-routes=false
```

In the Tailscale admin console → **Machines → management → Edit route settings** → enable `<your-ip-range>`.

After this, any device on your tailnet can reach any `<server-ip>` IP directly.

---

## 4. Set up ACL tags

Tags control which devices get access to what. In [Tailscale admin → ACLs](https://login.tailscale.com/admin/acls), define tag ownership and grants.

Example ACL config:

```json
{
  "tagOwners": {
    "tag:admin": ["autogroup:owner"],
    "tag:user":  ["autogroup:owner"],
    "tag:guest": ["autogroup:owner"]
  },
  "grants": [
    {
      "src": ["tag:admin"],
      "dst": ["100.64.0.0/10", "<your-ip-range>"],
      "ip": ["*"]
    },
    {
      "src": ["tag:admin", "tag:user"],
      "dst": ["<mgmt-ip>"],
      "ip": ["tcp:80", "tcp:443"]
    },
    {
      "src": ["tag:guest"],
      "dst": ["<guest-service-ts-ip>"],
      "ip": ["*"]
    },
    {
      "src": ["*"],
      "dst": ["<pihole-ts-ip>"],
      "ip": ["udp:53", "tcp:53"]
    }
  ]
}
```

**What each grant does:**

- `tag:admin` - full access to all Tailscale IPs and the entire LAN subnet, including admin <admin-port> on Traefik
- `tag:user` - Traefik port 80/443 only; Traefik's `ipAllowList` middleware further restricts which services are visible
- `tag:guest` - direct access to a specific node only (e.g. a game server or shared service)
- Everyone including untagged - DNS access to Pi-hole only; required because "Override local DNS" is tailnet-wide

Assign tags to devices in the Tailscale admin console → **Machines**.

!!! note "Two-layer access control"
    Tailscale ACLs control which ports a device can reach at the network level. Traefik's `ipAllowList` middleware controls which *services* are visible at the application level. Both layers work together - ACLs alone can't distinguish between services sharing port 443.

---

## 5. Verify

From a remote device connected to your tailnet:

```bash
# DNS resolves via Pi-hole
dig home.example.com
# Expected: <mgmt-ip>

# LAN is reachable via subnet route
ping <mgmt-ip>

# Internal HTTPS works remotely
curl -sk https://glance.home.example.com | head -5
```

---

## Day-2 operations

### Updating Tailscale

Tailscale auto-updates by default on most platforms. To update manually on any CT:

```bash
pct exec <vmid> -- tailscale update
```

Run this on each CT that has Tailscale installed (CT 100 and CT 101 in this setup, plus CT 400/401 if you set up Pterodactyl).

### Adding a device to your tailnet

Install Tailscale on the device and sign in with your account. Assign it a tag in the Tailscale admin console.

### Sharing access with someone else (e.g. Minecraft friends)

Use Tailscale's sharing feature: **admin console → Machines → Share** to invite someone to your tailnet with scoped access. Assign them `tag:minecraft` to limit their reach to game servers only.

### Re-authenticating a node

Tailscale nodes use ephemeral auth by default; they re-authenticate automatically. If a node shows as expired:

```bash
pct exec <vmid> -- tailscale up --accept-dns=false  # add other flags as needed
```

---

## Troubleshooting

**`*.home.example.com` not resolving on remote device**

1. Confirm Tailscale DNS is set to CT 101's **Tailscale IP** (not LAN IP) in the admin console
2. Confirm "Override local DNS" is enabled
3. Test DNS directly: `dig home.example.com @<pihole-ts-ip>` from the remote device
4. Confirm Pi-hole listening mode is **All Interfaces** (Settings → DNS → Interface settings)

**Subnet route not working**

1. Confirm the route is approved in Tailscale admin console → Machines → management → Edit route settings
2. Confirm CT 100 is running and Tailscale is up: `pct exec 100 -- tailscale status`
3. Check that your device has a route to `<your-ip-range>` via the subnet router: `ip route | grep 192.168.x` (macOS: `netstat -nr | grep 192.168.x`)

**Admin services reachable from non-admin Tailscale devices**

Verify the `tag:admin` grant is the only one that includes <admin-port> in your ACL config. The `ipAllowList` middleware in Traefik is a secondary layer - the ACL is the primary gate.
