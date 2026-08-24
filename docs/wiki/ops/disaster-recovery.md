---
title: Disaster Recovery
updated: 2026-08-08
---

# Disaster Recovery

Full rebuild from a clean Proxmox 8 install. Assumes the OS disk (`/dev/sdc`) was wiped; the data disks (`/dev/sdb` 2TB and `/dev/sda` 1TB) are intact with all service data.

**Estimated time:** 3–4 hours (mostly waiting for downloads and service startup)

---

## Pre-flight Checklist

- [ ] Proxmox 8 freshly installed on the OS disk (`/dev/sdc`)
- [ ] Run `lsblk` to confirm `sda` (1TB) and `sdb` (2TB) are detected
- [ ] `proxmox-admin` repo cloned or on a USB drive
- [ ] `scripts/.env` filled in - copy from `.env.example` and fill all values (KOMODO_* secrets, Cloudflare tokens, feeder config, all API keys)
- [ ] Tailscale auth key ready: tailscale.com/admin/settings/keys → generate ephemeral key
- [ ] Pi-hole password
- [ ] Subnet `<your-ip-range>`, gateway `<gateway-ip>`

> If data disks are also lost: service configs under `$DATA_ROOT/config/` need to be restored from backup. Media library is re-downloadable. Minecraft worlds (`$DATA_ROOT/minecraft/volumes/`) are irreplaceable - back these up.

---

## Scripts reference

All scripts live in `scripts/` and are idempotent.

| Script | Purpose | Run when |
|--------|---------|----------|
| `host-prep.sh` | Storage mounts, pvesm pools, dir tree, shared groups, Zigbee udev | Once on bare host |
| `common.sh` | Shared functions - sourced by CT scripts, not run directly | - |
| `ct<id>-<name>.sh` | Per-CT: users, chown, conf patches, start, Periphery install | After CT is created |

Set `KOMODO_CORE_ADDR=ws://<komodo-ip>:9120` before running any CT script.
Override Periphery version with `PERIPHERY_VERSION=<tag>` if needed (default: latest).

---

## Phase 1 - Proxmox Host Foundation (~10 min)

**1.1** Open a root shell on the Proxmox node.

**1.2** Clone the repo:
```bash
apt-get install -y git
git clone https://github.com/<your-username>/homelab /opt/proxmox-admin
cd /opt/proxmox-admin
```

**1.3** Run host prep. Verify disk devices first with `lsblk -o NAME,SIZE,MODEL`, then:
```bash
# Adjust DATA_DISK / MINECRAFT_DISK if your devices differ from the defaults (/dev/sdb1, /dev/sda1)
DATA_DISK=/dev/sdb1 MINECRAFT_DISK=/dev/sda1 bash scripts/host-prep.sh
```

**1.4** Verify:
```bash
pvesm status                        # data + minecraft pools listed
ls $DATA_ROOT/config/                # directory tree present
getent group media iot ultrafeeder  # shared groups created
```

---

## Phase 2 - Create LXCs + CT 100 offline setup (~30 min)

Use the [Proxmox community helper scripts](https://community-scripts.github.io/ProxmoxVE/) for all containers. Open the Proxmox shell and run the script for each CT below. Enter the custom values shown when prompted - don't accept defaults blindly.

Download the Debian 13 template before starting:
```bash
pveam update && pveam download local debian-13-standard_13.1-2_amd64.tar.zst
```

After creating **CT 100**, immediately run its setup script (offline only - CT 100 is started in Phase 6):
```bash
bash scripts/ct100-management.sh
```

### CT 100 - management (Docker)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/docker.sh)
```

| Setting  | Value                              |
| -------- | ---------------------------------- |
| CT ID    | 100                                |
| Hostname | management                         |
| Cores    | 2, RAM 2048MB, Disk 8GB            |
| IP       | <mgmt-ip>/24, GW <gateway-ip> |

### CT 101 - pihole
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/pihole.sh)
```

| Setting  | Value                                   |
| -------- | --------------------------------------- |
| CT ID    | 101                                     |
| Hostname | pihole                                  |
| Cores    | 4, CPU units 2048, RAM 1024MB, Disk 4GB |
| IP       | <pihole-ip>/24                       |

### CT 200 - ultrafeeder (Docker)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/docker.sh)
```

| Setting | Value                     |
| ------- | ------------------------- |
| CT ID   | 200, Hostname ultrafeeder |
| Cores   | 2, RAM 2048MB, Disk 8GB   |
| IP      | <ultrafeeder-ip>/24         |

### CT 201 - iot (Docker)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/docker.sh)
```

| Setting | Value                   |
| ------- | ----------------------- |
| CT ID   | 201, Hostname iot       |
| Cores   | 2, RAM 1024MB, Disk 8GB |
| IP      | <iot-ip>/24       |

### CT 202 - monitoring (Docker)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/docker.sh)
```

| Setting | Value                    |
| ------- | ------------------------ |
| CT ID   | 202, Hostname monitoring |
| Cores   | 2, RAM 1024MB, Disk 8GB  |
| IP      | <monitoring-ip>/24        |

### CT 300 - media-arr (Docker)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/docker.sh)
```

| Setting | Value                                 |
| ------- | ------------------------------------- |
| CT ID   | 300, Hostname media-arr               |
| Cores   | 4, CPU limit 2, RAM 4096MB, Disk 16GB |
| IP      | <media-arr-ip>/24                      |

### CT 301 - media-server (Docker)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/docker.sh)
```

| Setting | Value                                |
| ------- | ------------------------------------ |
| CT ID   | 301, Hostname media-server           |
| Cores   | 4, CPU limit 3, RAM 4096MB, Disk 8GB |
| IP      | <media-server-ip>/24                     |

### CT 302 - media-dl (Docker)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/docker.sh)
```

| Setting | Value                                |
| ------- | ------------------------------------ |
| CT ID   | 302, Hostname media-dl               |
| Cores   | 2, CPU limit 2, RAM 1024MB, Disk 8GB |
| IP      | <media-dl-ip>/24                     |

### CT 400 - game-panel
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/pterodactyl-panel.sh)
```

| Setting | Value                               |
| ------- | ----------------------------------- |
| CT ID   | 400, Hostname game-panel            |
| Cores   | 2, RAM 1024MB, Swap 512MB, Disk 8GB |
| IP      | <panel-ip>/24                    |

### CT 401 - minecraft-wings
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/pterodactyl-wings.sh)
```

| Setting | Value                         |
| ------- | ----------------------------- |
| CT ID   | 401, Hostname minecraft-wings |
| Cores   | 6, RAM 20480MB, Disk 16GB     |
| IP      | <wings-ip>/24              |

### CT 600 - personal-apps (Docker)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/docker.sh)
```

| Setting | Value                        |
| ------- | ---------------------------- |
| CT ID   | 600, Hostname personal-apps  |
| Cores   | 2, RAM 2048MB, Disk 8GB      |
| IP      | <personal-apps-ip>/24             |

---

## Phase 3 - Run CT Scripts (~30 min)

Each CT script patches the LXC conf, sets directory ownership, starts the CT, and installs Periphery. Periphery agents will connect to Komodo Core once it's running (Phase 6).

```bash
# Once: fill in the root env file before running any CT script
cp scripts/.env.example scripts/.env
nano scripts/.env   # fill in all values

cd /opt/proxmox-admin
bash scripts/ct101-pihole.sh     # pihole first - DNS up before others
bash scripts/ct200-ultrafeeder.sh
bash scripts/ct201-iot.sh
bash scripts/ct202-monitoring.sh
bash scripts/ct300-media-arr.sh
bash scripts/ct301-media-server.sh
bash scripts/ct302-media-dl.sh
bash scripts/ct600-personal-apps.sh
# ct400 and ct401 are handled in Phase 8 (Pterodactyl)
```

CT 100 (management) was patched in Phase 2 and is started manually in Phase 6.

Each CT script reads `scripts/.env`, installs Periphery with the correct `KOMODO_CORE_ADDR`, and pre-deploys compose files and `.env` files to each stack directory on the host. Stack files are in place before Komodo boots in Phase 6.

---

## Phase 4 - Pi-hole (CT 101) (~15 min)

CT 101 was started by `ct101-pihole.sh` in Phase 3. Configure it now before deploying other services - DNS must be up for `*.home.example.com` resolution.

**4.1** Set listening mode so Tailscale clients (100.x.x.x) can query:
```bash
pct exec 101 -- sed -i 's/listeningMode = .*/listeningMode = "ALL"/' /etc/pihole/pihole.toml
pct exec 101 -- pihole restartdns
```

**4.2** Configure Unbound. Push the config files:
```bash
pct exec 101 -- apt-get install -y unbound

# home-internal.conf - wildcard redirect for the internal domain
pct exec 101 -- bash -c 'cat > /etc/unbound/unbound.conf.d/home-internal.conf << EOF
server:
    local-zone: "home.example.com." redirect
    local-data: "home.example.com. A <mgmt-ip>"
EOF'

# homelab.conf - performance tuning (name is legacy, the .homelab zone is retired)
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

# z-performance.conf (must sort after pi-hole.conf to override num-threads: 1)
pct exec 101 -- bash -c 'cat > /etc/unbound/unbound.conf.d/z-performance.conf << EOF
server:
    num-threads: 2
    so-reuseport: yes
EOF'

pct exec 101 -- systemctl enable --now unbound
```

**4.3** In Pi-hole admin UI (`http://<pihole-ip>/admin`):
- Upstream DNS → set to `127.0.0.1#5335` (Unbound only)
- Remove all external forwarders

**4.4** Update router DHCP settings:
- LAN → DHCP → DNS Server 1: `<pihole-ip>`
- DNS Server 2: `1.1.1.1` (fallback)

**4.5** Verify:
```bash
dig home.example.com @<pihole-ip>     # → <mgmt-ip>
dig google.com @<pihole-ip>  # → resolves
```

See [pihole](../lxcs/pihole.md) for full config reference.

---

## Phase 5 - Docker Daemon Config (~5 min)

All Docker LXCs need MTU 1450 to prevent fragmentation issues on this network (ISP MTU). Apply to each Docker CT - they're all running now:

```bash
for ct in 200 201 202 300 301 302 600; do
    pct exec $ct -- bash -c 'mkdir -p /etc/docker && cat > /etc/docker/daemon.json << EOF
{
  "log-driver": "journald",
  "mtu": 1450
}
EOF
systemctl restart docker'
    echo "CT $ct: daemon configured"
done
```

> **Troubleshooting:** if Docker image pulls time out or fail with connection errors, add `"registry-mirrors": ["https://mirror.gcr.io"]` to `daemon.json`. This ISP occasionally blocks Cloudflare R2 (Docker Hub's CDN).

---

## Phase 6 - Komodo Core Bootstrap (CT 100) (~15 min)

**6.1** Copy the bootstrap compose and fill in secrets:
```bash
pct exec 100 -- mkdir -p /opt/komodo
pct push 100 stacks/management/komodo/compose.yaml /opt/komodo/compose.yaml
pct push 100 stacks/management/komodo/compose.env.example /opt/komodo/compose.env

# Fill in secrets - values are in scripts/.env:
# pct enter 100  →  then edit /opt/komodo/compose.env (copy KOMODO_* vars from .env)
```

**6.2** Configure Docker daemon on CT 100:
```bash
pct exec 100 -- bash -c 'mkdir -p /etc/docker && cat > /etc/docker/daemon.json << EOF
{
  "log-driver": "journald",
  "mtu": 1450
}
EOF
systemctl restart docker'
```

**6.3** Start Komodo:
```bash
pct exec 100 -- bash -c 'cd /opt/komodo && docker compose --env-file compose.env -f compose.yaml up -d'
```

**6.4** Wait ~30 seconds, open `http://<mgmt-ip>:9120`, create the admin account.

**6.5** Add all servers (Settings → Servers → Add). Use `wss://` for the address. Periphery was pre-installed in Phase 3 - servers should turn green within ~30 seconds of being added.

| Server | Address |
|--------|---------|
| management (Local) | `wss://<mgmt-ip>:8120` |
| pihole | `wss://<pihole-ip>:8120` |
| ultrafeeder | `wss://<ultrafeeder-ip>:8120` |
| iot | `wss://<iot-ip>:8120` |
| monitoring | `wss://<monitoring-ip>:8120` |
| media-arr | `wss://<media-arr-ip>:8120` |
| media-server | `wss://<media-server-ip>:8120` |
| media-dl | `wss://<media-dl-ip>:8120` |
| game-panel | `wss://<panel-ip>:8120` _(after Phase 8)_ |
| personal-apps | `wss://<personal-apps-ip>:8120` |

Enable each server after adding (created as `enabled: false` by default).

---

## Phase 7 - Deploy Stacks via Komodo (~30 min)

The CT scripts (Phase 3) pre-deployed compose files and `.env` files to each stack directory. In Komodo, register each stack in "files on host" mode pointing to the existing files and deploy - no manual file copying needed. See [komodo](../infrastructure/komodo.md) for the stack creation workflow.

Deploy in this order (Traefik first, cloudflared depends on Traefik):

**Management stacks** (Periphery root: `/data/config/management/komodo/periphery`):
1. `traefik`
2. `cloudflared`
3. `glance`, `filebrowser`, `node-exporter-local`

**All other stacks** (Periphery root: `/data/komodo`, order doesn't matter):

| Server | Stacks |
|--------|--------|
| monitoring | `monitoring`, `node-exporter-monitoring` |
| ultrafeeder | `ultrafeeder`, `node-exporter-ultrafeeder` |
| iot | `iot`, `node-exporter-iot` |
| media-arr | `media-arr`, `node-exporter-media-arr` |
| media-server | `media-server`, `node-exporter-media-server` |
| media-dl | `media-dl`, `node-exporter-media-dl` |
| personal-apps | `actual-budget` |

After deploying `monitoring`, push the monitoring config files (not managed by Komodo):
```bash
pct push 202 stacks/monitoring/prometheus.yml /data/prometheus.yml
pct push 202 stacks/monitoring/pve.yml /data/pve-exporter/pve.yml
pct exec 202 -- chmod 644 /data/prometheus.yml /data/pve-exporter/pve.yml
```

> **pve-exporter token:** if the PVE API token was lost with the OS disk, recreate it: `pveum user token add pve-exporter@pve metrics --privsep 0`. Assign PVEAuditor role at `/`. See [monitoring](../lxcs/monitoring.md).

---

## Phase 8 - Pterodactyl Panel + Wings (CT 400/401) (~30 min)

Run the CT scripts first - they patch the conf, start the CTs, and install Periphery:
```bash
export KOMODO_CORE_ADDR=ws://<mgmt-ip>:9120
bash scripts/ct400-game-panel.sh
bash scripts/ct401-minecraft-wings.sh
```

The helper scripts ran the full Pterodactyl/Wings install during CT creation (Phase 2). Now restore data and connect Wings.

**8.1** Restore Panel data (if `$DATA_ROOT/config/panel/` has the backup):
The install symlinked `/opt/pterodactyl-panel/storage → /data/storage` and `.env → /data/.env`, so Panel is already using the restored data. Restart services:
```bash
pct exec 400 -- systemctl restart apache2 php8.4-fpm mariadb
```

**8.2** Restore Wings config. The install already created Wings; configure it using the token from the panel:
```bash
pct exec 401 -- bash -c 'ln -sf /data/pterodactyl /etc/pterodactyl'
```
If `/data/pterodactyl/config.yml` exists from backup, Wings uses it immediately. Otherwise, create the node in the panel and run the configure command it generates.

**8.3** Fix Wings systemd - prevent startup failure when Tailscale isn't ready:
```bash
pct exec 401 -- bash -c '
    mkdir -p /etc/systemd/system/wings.service.d
    cat > /etc/systemd/system/wings.service.d/tailscale.conf << EOF
[Service]
After=tailscaled.service
ExecStartPre=/bin/sleep 10
EOF
    systemctl daemon-reload && systemctl restart wings'
```

---

## Phase 9 - Tailscale (~15 min)

The community helper scripts add `lxc.cgroup2.devices.allow` + `lxc.mount.entry` entries for TUN - **these don't work**. The CT scripts added the correct `dev0` entry, but you need to remove the bad entries added by the helper scripts first.

For each Tailscale CT (100, 101, 400, 401):

```bash
vmid=100   # repeat for 101, 400, 401
pct stop $vmid

# Remove bad entries if the helper script added them
sed -i '/lxc.cgroup2.devices.allow: c 10:200/d' /etc/pve/lxc/$vmid.conf
sed -i '/lxc.mount.entry: \/dev\/net\/tun/d' /etc/pve/lxc/$vmid.conf
# Confirm dev0 is present (added by the CT script)
grep 'dev/net/tun' /etc/pve/lxc/$vmid.conf

pct start $vmid
pct exec $vmid -- bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/addon/add-tailscale-lxc.sh)
```

Authenticate each:

| CT | Command |
|----|---------|
| 100 | `tailscale up --advertise-routes=<your-ip-range> --accept-dns=false --accept-routes=false` |
| 101 | `tailscale up --accept-routes=false --accept-dns=false` |
| 400 | `tailscale up --accept-routes=false --accept-dns=false` |
| 401 | `tailscale up --accept-routes=false --accept-dns=false` |

After CT 100 authenticates: Tailscale admin → Machines → management → Edit route settings → enable `<your-ip-range>`.

After CT 101 authenticates: Tailscale admin → DNS → Global nameserver: `<pihole-ts-ip>`, Override local DNS: on.

> Tailscale IPs change on re-auth. Update Wings node FQDN in the panel if CT 401's IP changed (old: `<wings-ts-ip>`). Also update `allowed_origins` in Wings config if CT 400's IP changed.

---

## Phase 10 - Verify (~10 min)

```bash
# All CTs running
for ct in 100 101 200 201 202 300 301 302 400 401 600; do
    printf "CT %-4s %s\n" $ct "$(pct status $ct)"
done

# DNS
dig home.example.com @<pihole-ip>

# Core services
curl -sf http://<mgmt-ip>:9120/health  # Komodo
curl -sf http://<mgmt-ip>:8080/ping    # Traefik
curl -sf http://<media-server-ip>:8096/health   # Jellyfin
```

Open `https://glance.home.example.com` → Services page - all monitors should go green.

---

## Key Takeaways

- All scripts are idempotent - re-run any phase that partially fails
- Data disks survive the rebuild - `$DATA_ROOT/config/` has all service state
- Komodo secrets must be in a password manager - not stored in repo
- Tailscale IPs change on re-auth - update Wings node FQDN and `allowed_origins`
- CT scripts handle conf patching, start, and Periphery install - run one per CT after creation
- Docker MTU 1450 is required; registry mirror (`https://mirror.gcr.io`) is an optional fallback for pull failures
- See [lxc inventory](../lxcs/lxc-inventory.md) for full CT spec reference
