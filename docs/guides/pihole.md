# DNS - Pi-hole + Unbound

## What you'll end up with

Pi-hole running as your LAN DNS server with Unbound as a local recursive resolver - no external DNS provider in the chain. All `*.home.example.com` queries resolve to your reverse proxy. Tailscale clients use Pi-hole as their nameserver so internal domains work from anywhere on your tailnet.

---

## Prerequisites

- Proxmox host set up and reachable
- A static IP reserved for CT 101 on your router (or set a static DHCP lease)
- The repo cloned on the Proxmox host at `/opt/proxmox-admin`

---

## 1. Create the LXC

Use the Pi-hole community helper script from a Proxmox root shell. This installs Pi-hole inside the container automatically.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/pihole.sh)
```

When prompted, set:

| Setting | Value |
|---------|-------|
| CT ID | 101 |
| Hostname | pihole |
| Cores | 4 |
| CPU units | 2048 |
| RAM | 1024 MB |
| Disk | 4 GB |
| IP | <pihole-ip>/24 |
| Gateway | <gateway-ip> |

Partway through the installation, the script will ask:

```
Would you like to add Unbound? <y/N>
```

Answer **y**. Then it asks whether to use Unbound as a recursive resolver or a forwarding server with DNS-over-TLS - choose **recursive** (the default). The script installs Unbound and wires it to Pi-hole as the upstream automatically.

---

## 2. Run the CT script

The CT script patches the LXC config to allow the TUN device (needed for Tailscale later) and installs the Periphery agent so Komodo can manage this CT.

```bash
cd /opt/proxmox-admin
bash scripts/ct101-pihole.sh
```

What it does:

- Adds `dev0: /dev/net/tun,gid=0,uid=0` to `/etc/pve/lxc/101.conf`
- Installs the Komodo Periphery binary agent
- Starts CT 101 and waits for it to be ready

---

## 3. Configure Pi-hole

Open the Pi-hole admin UI at `http://<pihole-ip>/admin`.

### Set listening mode

Go to **Settings → DNS → Interface settings** and set the listening mode to **All Interfaces**.

The default "Allow only local requests" mode blocks DNS queries arriving over Tailscale (which uses the `100.x.x.x` range), so remote devices on your tailnet won't be able to use Pi-hole as their nameserver. Setting this to All Interfaces fixes that.

### Verify upstream DNS

Go to **Settings → DNS** and confirm the upstream DNS is already set to `127.0.0.1#5335` (Unbound). The install script should have set this automatically.

If it isn't set:

- Uncheck all default upstream servers (Google, Cloudflare, etc.)
- Check **Custom 1 (IPv4)** and enter `127.0.0.1#5335`
- Save - Pi-hole will restart its DNS service.

---

## 4. Additional Unbound configuration

The installer set up Unbound as a recursive resolver and wired it to Pi-hole. What it didn't add is the homelab-specific config: an internal domain redirect so `*.home.example.com` resolves to your Traefik IP, and some performance tuning.

### Internal domain redirect

Create `/etc/unbound/unbound.conf.d/home-internal.conf` inside CT 101. This makes every `*.home.example.com` query return your Traefik IP.

```bash
pct exec 101 -- bash -c 'cat > /etc/unbound/unbound.conf.d/home-internal.conf << EOF
server:
    local-zone: "home.example.com." redirect
    local-data: "home.example.com. A <mgmt-ip>"
EOF'
```

Replace `home.example.com` with your actual internal domain and `<mgmt-ip>` with your Traefik host IP.

### Performance tuning

```bash
pct exec 101 -- bash -c 'cat > /etc/unbound/unbound.conf.d/homelab.conf << EOF
server:
    num-threads: 2
    outgoing-range: 256
    num-queries-per-thread: 1024
    prefetch: yes
    prefetch-key: yes
    serve-expired: yes
    edns-buffer-size: 1232
EOF'
```

```bash
pct exec 101 -- bash -c 'cat > /etc/unbound/unbound.conf.d/z-performance.conf << EOF
server:
    num-threads: 2
    so-reuseport: yes
EOF'
```

!!! note "Why `z-performance.conf`?"
    Unbound loads config files in alphabetical order. Pi-hole generates its own `/etc/unbound/unbound.conf.d/pi-hole.conf` which sets `num-threads: 1`. The `z-` prefix ensures this file sorts *after* `pi-hole.conf` and overrides that setting.

### Restart Unbound

```bash
pct exec 101 -- systemctl restart unbound
```

---

## 5. Configure your router

Tell your router to hand out Pi-hole as the DNS server for all DHCP clients.

In your router's DHCP settings:

| Field | Value |
|-------|-------|
| DNS Server 1 | `<pihole-ip>` |
| DNS Server 2 | *(leave empty)* |

**Leave the fallback empty.** If Pi-hole goes down, you want DNS to fail visibly - not silently fall back to an external server that bypasses your blocklists. This is intentional.

Renew DHCP leases on your devices (or just wait for them to expire) and they'll start using Pi-hole.

---

## 6. Add blocklists

In the Pi-hole admin UI, go to **Adlists** and add:

| Name | URL |
|------|-----|
| StevenBlack unified | `https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts` |
| HaGeZi Multi PRO | `https://raw.githubusercontent.com/hagezi/dns-blocklists/main/hosts/pro.txt` |

Then go to **Tools → Update Gravity** to apply them.

---

## 7. Traefik integration (after Traefik is set up)

Once Traefik is running, you can access the Pi-hole admin UI at `https://pihole.home.example.com:<admin-port>` instead of the direct IP.

No extra Pi-hole configuration needed for this. Traefik routes based on hostname, and Unbound already resolves `*.home.example.com` to Traefik's IP.

---

## 8. Tailscale DNS (after Tailscale is set up)

Once Tailscale is installed on CT 101, configure Pi-hole as the DNS nameserver for your entire tailnet.

In the [Tailscale admin console](https://login.tailscale.com/admin/dns):

- **Global nameserver**: enter the **Tailscale IP** of CT 101 (shown on the Machines page after it authenticates - it'll be a `100.x.x.x` address)
- **Override local DNS**: enable
- **MagicDNS**: enable

!!! warning "Use the Tailscale IP, not the LAN IP"
    Set the nameserver to CT 101's **Tailscale IP** (`100.x.x.x`), not its LAN IP (`<pihole-ip>`). Remote Tailscale devices can't reach LAN IPs directly - they can only reach other Tailscale nodes.

---

## 9. Verify

```bash
# Internal domain resolves to Traefik
dig home.example.com @<pihole-ip>
# Expected: <mgmt-ip>

# External DNS works (Unbound resolving from root servers)
dig google.com @<pihole-ip>
# Expected: real IP for google.com

# Unbound is responding
dig google.com @127.0.0.1 -p 5335
# Run inside CT 101: pct exec 101 -- dig google.com @127.0.0.1 -p 5335
```

Check the Pi-hole admin UI - you should see query activity from your LAN devices populating the dashboard.

---

## Day-2 operations

### Updating Pi-hole and Unbound

Both were installed via the Proxmox community helper script. The `update` command handles both. Open the CT 101 console in the Proxmox UI and run:

```bash
update
```

### Checking query logs

Pi-hole admin UI → **Query Log** - shows every DNS query, what resolved it, and whether it was blocked.

### Adding a custom DNS entry

For a device you want to reach by name on your LAN (e.g. a printer at `<example-device-ip>`), go to **Local DNS → DNS Records** in the Pi-hole UI and add an A record.

### Temporarily disabling blocking

Pi-hole admin UI → **Dashboard** → **Disable** (with a time limit). Useful for debugging connectivity issues.

---

## Troubleshooting

**TCP connection errors for Unbound in Pi-hole logs**

You may see entries like `connection refused 127.0.0.1:5335 (TCP)` in Pi-hole's logs. These are harmless. Pi-hole v6 probes upstream servers over TCP as a health check, but Unbound only responds to DNS queries on UDP. Everything works correctly - the error is noise.

**Tailscale devices not resolving internal domains**

1. Confirm the Tailscale admin DNS nameserver is set to CT 101's **Tailscale IP**, not its LAN IP.
2. Confirm Pi-hole listening mode is **All Interfaces**, not "Allow only local requests".
3. Run `dig home.example.com @<pihole-tailscale-ip>` from a remote device to test directly.

**Pi-hole not receiving queries after router change**

Renew your DHCP lease: on macOS `sudo ipconfig set en0 BOOTP && sudo ipconfig set en0 DHCP`, on Linux `sudo dhclient -r && sudo dhclient`. Windows: `ipconfig /release && ipconfig /renew`.

**`*.home.example.com` not resolving**

Check the Unbound redirect zone config:
```bash
pct exec 101 -- cat /etc/unbound/unbound.conf.d/home-internal.conf
pct exec 101 -- systemctl status unbound
```

If Unbound isn't running, start it with `pct exec 101 -- systemctl start unbound`, then verify with `pct exec 101 -- dig home.example.com @127.0.0.1 -p 5335`.
