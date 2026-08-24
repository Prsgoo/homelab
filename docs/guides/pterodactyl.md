# Game Servers - Pterodactyl Panel + Wings

## What you'll end up with

Pterodactyl Panel in CT 400 (the web UI for creating and managing game servers) and Pterodactyl Wings in CT 401 (the daemon that actually runs the containers). Panel is accessible via Traefik at `https://game-panel.home.example.com`. Wings connects to Panel over Tailscale so friends can also connect to game servers without needing your LAN IP.

---

## Prerequisites

- Komodo running
- Traefik running
- Tailscale installed on CT 400 and CT 401 (handled in this guide)
- The minecraft disk mounted at `$DATA_ROOT/minecraft` (done by `host-prep.sh`)

---

## 1. Create CT 400 (Panel)

The community helper script installs Pterodactyl Panel natively (Apache + PHP):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/pterodactyl-panel.sh)
```

| Setting | Value |
|---------|-------|
| CT ID | 400 |
| Hostname | game-panel |
| Cores | 2 |
| RAM | 1024 MB |
| Swap | 512 MB |
| Disk | 8 GB |
| IP | <panel-ip>/24 |

The helper script runs the full Pterodactyl Panel installation interactively. Follow the prompts - it will ask for a database password, admin email, and Panel URL.

For the Panel URL, use your Traefik domain: `https://game-panel.home.example.com`

---

## 2. Create CT 401 (Wings)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/pterodactyl-wings.sh)
```

| Setting | Value |
|---------|-------|
| CT ID | 401 |
| Hostname | minecraft-wings |
| Cores | 6 |
| RAM | 20480 MB |
| Disk | 16 GB |
| IP | <wings-ip>/24 |

Give Wings the RAM budget for however many Minecraft servers you plan to run simultaneously. 20 GB supports 4�5 servers comfortably.

---

## 3. Run the CT scripts

```bash
cd /opt/proxmox-admin
bash scripts/ct400-game-panel.sh
bash scripts/ct401-minecraft-wings.sh
```

CT 400's script: sets bind mount for Panel data, TUN device for Tailscale, installs Periphery.

CT 401's script: sets bind mounts for server volumes and backups, TUN device, installs Periphery.

---

## 4. Install Tailscale on both CTs

Wings needs to be reachable by the Panel (and by friends) over Tailscale. Install on both:

```bash
# CT 400 (Panel)
pct exec 400 -- bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/addon/add-tailscale-lxc.sh)

# CT 401 (Wings)
pct exec 401 -- bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/addon/add-tailscale-lxc.sh)
```

Clean up bad TUN entries for both:

```bash
for vmid in 400 401; do
  pct stop $vmid
  sed -i '/lxc.cgroup2.devices.allow: c 10:200/d' /etc/pve/lxc/$vmid.conf
  sed -i '/lxc.mount.entry: \/dev\/net\/tun/d' /etc/pve/lxc/$vmid.conf
  pct start $vmid
done
```

Authenticate each:

```bash
pct exec 400 -- tailscale up --accept-routes=false --accept-dns=false
pct exec 401 -- tailscale up --accept-routes=false --accept-dns=false
```

Note the Tailscale IP assigned to CT 401 (Wings) - you'll use it as the node FQDN in the Panel.

---

## 5. Fix Wings systemd startup

Wings binds to its Tailscale IP. If it starts before Tailscale assigns that IP, it crashes. Add a startup delay:

```bash
pct exec 401 -- bash -c '
mkdir -p /etc/systemd/system/wings.service.d
cat > /etc/systemd/system/wings.service.d/tailscale.conf << EOF
[Unit]
After=network.target tailscaled.service

[Service]
ExecStartPre=/bin/sleep 10
EOF
systemctl daemon-reload'
```

---

## 6. Configure the Panel

Open the Panel at `http://<panel-ip>` (or via Traefik if you've added the route first).

Log in with the admin account created during installation.

**Add a node** (Wings) - go to **Admin → Nodes → Create New**:

| Setting | Value |
|---------|-------|
| Name | `local` (or anything descriptive) |
| FQDN | CT 401's Tailscale IP (the `100.x.x.x` address) |
| Communicate over SSL | Off |
| Daemon Port | `8080` |
| Daemon SFTP Port | `2022` |

Using the Tailscale IP as the FQDN means the node is reachable by anyone on your tailnet - including friends you've invited - without exposing any public ports.

**Get the Wings config token**: After creating the node, go to **Configuration** tab → copy the `wings configure` command shown.

---

## 7. Configure Wings

Run the configure command (from step 6) inside CT 401:

```bash
pct exec 401 -- wings configure \
  --panel-url https://game-panel.home.example.com \
  --token <node-token> \
  --node <node-id>
```

This writes `/etc/pterodactyl/config.yml`.

**Set CORS allowed origins** - edit the config to allow the Panel's URLs:

```bash
pct exec 401 -- nano /etc/pterodactyl/config.yml
```

Add to the `allowed_origins` list:

```yaml
allowed_origins:
  - https://game-panel.home.example.com
  - http://<panel-ip>
  - http://<panel-ts-ip>
```

Without the Panel's URL in `allowed_origins`, the browser console WebSocket connection is blocked and you can't see server logs in the UI.

**Restart Wings:**

```bash
pct exec 401 -- systemctl restart wings
```

Back in the Panel → **Nodes**, the node should show green (heartbeat active).

---

## 8. Add a server

In the Panel → **Servers → Create New**:

1. Pick an egg (game type - e.g. "Paper" for Minecraft Java)
2. Set the node to `local`
3. Set CPU/RAM/disk limits
4. Deploy

Wings downloads the egg's Docker image and starts the server. Minecraft Java servers listen on port 25565 by default.

---

## Giving friends access

Friends need a way to reach the game server. Options:

**Tailscale** - invite friends to your tailnet. They connect to Wings' Tailscale IP directly (`100.x.x.x:25565`). No port forwarding needed. If you want to scope their access to only the game server rather than your full tailnet, create a dedicated tag for it - the [Tailscale guide](tailscale.md) covers tags and grants.

**Port forwarding** - forward port 25565 (and any others your servers use) on your router to CT 401's LAN IP. Works if your ISP gives you a real public IP, but exposes the port publicly.

---

## Day-2 operations

### Updating Panel and Wings

Both were installed via the Proxmox community helper script. Open the console for each CT in the Proxmox UI and run:

```bash
update
```

Run this on CT 400 (Panel) and CT 401 (Wings) separately. Update Panel first, then Wings - they must be on matching versions.

### Starting and stopping servers

Panel UI → **Servers** → click a server → **Console** → Start/Stop buttons. Wings handles everything.

### Backups

Pterodactyl has a built-in backup system: **Server → Backups → Create Backup**. Backups land in `$DATA_ROOT/minecraft/backups/` on the host (bound into CT 401 at `/var/lib/pterodactyl/backups`).

!!! warning "Minecraft worlds are irreplaceable"
    Unlike media files, Minecraft worlds can't be re-downloaded. Back up `$DATA_ROOT/minecraft/` regularly to external storage.

### `artisan` commands on the Panel

Always run as `www-data`, not root:

```bash
pct exec 400 -- sudo -u www-data php /opt/pterodactyl-panel/artisan <command>
```

Running as root creates root-owned cache files that break Apache.

---

## Troubleshooting

**Node showing offline in Panel**

1. Confirm Wings is running: `pct exec 401 -- systemctl status wings`
2. Confirm Tailscale is up on CT 401: `pct exec 401 -- tailscale status`
3. Check Wings logs: `pct exec 401 -- journalctl -u wings -n 50`
4. Wings may have started before Tailscale - the systemd startup fix (step 5) prevents this, but if you skipped it, restart Wings after Tailscale is up

**Browser console broken (WebSocket error)**

`allowed_origins` in Wings config doesn't include the Panel URL. Add it and restart Wings.

**Server won't start / "Error pulling image"**

Wings containers need internet access to pull Docker images. Check that CT 401 can reach Docker registries:

```bash
pct exec 401 -- docker pull itzg/minecraft-server
```

If it fails, check MTU (should be 1450 in daemon.json) and network config.

**Friends can't connect to game server via Tailscale**

1. Confirm they're on your tailnet and have `tag:minecraft` assigned
2. Confirm the Tailscale ACL grants `tag:minecraft` access to CT 401's Tailscale IP
3. The Panel node FQDN must be CT 401's Tailscale IP - if it changed after re-auth, update it in Panel → Nodes
