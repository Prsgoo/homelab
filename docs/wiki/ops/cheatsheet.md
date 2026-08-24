---
title: Cheatsheet
updated: 2026-08-05
---

# Cheatsheet

Quick reference for common ops tasks. All commands run on the **Proxmox host as root** unless noted.

---

## LXC Management

```bash
# Start / stop / restart
pct start <vmid>
pct stop <vmid>
pct reboot <vmid>

# Run a command inside a container without entering it
pct exec <vmid> -- <command>

# Open a shell inside a container
pct enter <vmid>

# Show current config
pct config <vmid>

# Set resources (while stopped)
pct set <vmid> -memory 2048 -cores 4

# Resize rootfs - takes effect immediately, no stop required for lvmthin
# WARNING: check pool headroom FIRST (see "local-lvm Thin Pool Full" below) - if the
# pool is near 100%, the LV's virtual size grows but resize2fs can't run, leaving the
# filesystem ungrown and potentially breaking the next container start.
pct resize <vmid> rootfs 16G        # set to absolute size
pct resize <vmid> rootfs +5G        # grow by amount

# List all volumes for a container
pvesm list local-lvm | grep vm-<vmid>

# Check disk usage inside a container
pct exec <vmid> -- df -h

# Delete a volume (must be detached first - i.e. container deleted or disk removed from config)
pvesm free local-lvm:vm-<vmid>-disk-<n>
```

---

## local-lvm Thin Pool Full

A weekly cron job already runs `fstrim` on every running container, so this section is mainly for manual checks/emergencies.

Check pool headroom before resizing any LXC rootfs, or if a container fails to boot with
`lxc.hook.pre-start ... Failed to initialize container` (exit 32):

```bash
# Pool usage - look at the "data" LV row (the thin pool itself)
lvs -a --units g -o lv_name,vg_name,lv_size,data_percent,metadata_percent
```

If `data_percent` is at/near 100%, reclaim deleted-but-untrimmed blocks right away
(non-destructive, no data loss - safe to run anytime):

```bash
/usr/local/bin/fstrim-containers.sh
```

Re-check `lvs` afterward. See [storage layout](../storage/storage-layout.md) for pool history.

### Automated fstrim cron (setup reference)

Runs every Sunday 03:00, loops over whatever containers are currently running, logs to `/var/log/fstrim-containers.log`.

`/usr/local/bin/fstrim-containers.sh`:
```bash
#!/bin/bash
for ct in $(pct list | awk '$2=="running" {print $1}'); do
  pct fstrim "$ct"
done
```

`/etc/cron.d/fstrim-containers`:
```
0 3 * * 0 root /usr/local/bin/fstrim-containers.sh >> /var/log/fstrim-containers.log 2>&1
```

---

## Filesystem Didn't Grow After `pct resize`

Check for a mismatch between the configured LV size and what the container's filesystem sees:

```bash
pct config <vmid> | grep rootfs        # configured LV size
pct exec <vmid> -- df -h /             # actual filesystem size
```

If the LV is bigger than the filesystem, online `resize2fs` on a running container fails:

```
resize2fs: Device or resource busy while trying to open /dev/pve/vm-<vmid>-disk-0
Couldn't find valid filesystem superblock.
```

Fix with an offline resize (~30s downtime):

```bash
pct stop <vmid>
e2fsck -f /dev/pve/vm-<vmid>-disk-0
resize2fs /dev/pve/vm-<vmid>-disk-0
pct start <vmid>
pct exec <vmid> -- df -h /              # confirm new size
```

`e2fsck -f` may prompt `Deleted inode N has zero dtime. Fix<y>?` - safe to answer `y`
(or use `e2fsck -fy` to auto-confirm).

---

## Static IP

Set at container creation or after the fact:

```bash
pct set <vmid> -net0 name=eth0,bridge=vmbr0,ip=<server-ip>/24,gw=<gateway-ip>,hwaddr=<mac>
```

Or edit `/etc/pve/lxc/<vmid>.conf` directly:

```
net0: name=eth0,bridge=vmbr0,gw=<gateway-ip>,hwaddr=BC:24:11:XX:XX:XX,ip=<server-ip>/24,type=veth
```

IP ranges in use: `.100`–`.101` (infrastructure), `.200`–`.202` (ultrafeeder, iot, monitoring), `.30`–`.32` (media), `.40`–`.41` (gaming), `.60` (personal-apps).

---

## Bind Mounts

Add or change a bind mount (container must be stopped):

```bash
pct set <vmid> -mp0 $DATA_ROOT/config/<name>,mp=/data
```

Or directly in `/etc/pve/lxc/<vmid>.conf`:

```
mp0: $DATA_ROOT/config/<name>,mp=/data
mp1: $DATA_ROOT/media-stack/media,mp=/media,ro=1
```

Always create the host directory and set ownership before starting the container - see [lxc idmap](../standards/lxc-idmap.md).

---

## Bind Mount Ownership & ACLs

### Standard pattern for service-owned mounts (with idmap block)

```bash
# Bind mount root - owned by container root (host UID 100000), traversable by service group
chown 100000:<group-gid> $DATA_ROOT/config/<name>/
chmod 750 $DATA_ROOT/config/<name>/

# Per-service subdirectory
chown <uid>:<group-gid> $DATA_ROOT/config/<name>/<service>/
chmod 750 $DATA_ROOT/config/<name>/<service>/
```

### Management LXC (no idmap - runs as root, host UID 100000)

```bash
# Grant CT 100 traversal of pool root and config/ (run once, or after adding new top-level dirs)
setfacl -m u:100000:rx $DATA_ROOT
setfacl -m u:100000:rx $DATA_ROOT/config

# Full access (rwx + default ACL so new files inherit) for CT 100 on a data subdirectory
setfacl -Rm u:100000:rwx $DATA_ROOT/<dir>
setfacl -Rdm u:100000:rwx $DATA_ROOT/<dir>

# CT 100 must own its own config directory
chown -R 100000:100000 $DATA_ROOT/config/management
```

### Check / strip ACLs

```bash
getfacl $DATA_ROOT/<path>
setfacl -b $DATA_ROOT/<path>   # strip all ACLs if they're blocking writes
```

---

## idmap Block

Add to `/etc/pve/lxc/<vmid>.conf` before first start (requires Proxmox root shell - API cannot set this):

```bash
cat >> /etc/pve/lxc/<vmid>.conf << 'EOF'
lxc.idmap: u 0 100000 1000
lxc.idmap: u 1000 1000 500
lxc.idmap: u 1500 101500 64036
lxc.idmap: g 0 100000 1000
lxc.idmap: g 1000 1000 500
lxc.idmap: g 1500 101500 64036
EOF
```

See [lxc idmap](../standards/lxc-idmap.md) for which LXCs need this and why.

---

## Device Passthrough (USB serial / TUN)

For specific character devices (TUN, serial), use `dev0`. For a full USB bus (CT 200 RTL-SDR), `lxc.cgroup2.devices.allow` + `lxc.mount.entry` are required - `dev0` only supports char devices, not directory mounts.

```bash
# Zigbee USB dongle (CT 201)
# In /etc/pve/lxc/201.conf:
dev0: /dev/ttyUSB0,gid=1200,uid=0

# Tailscale TUN device (any LXC with Tailscale)
# In /etc/pve/lxc/<vmid>.conf:
dev0: /dev/net/tun,gid=0,uid=0
```

If the Tailscale helper script added bad entries, clean them first:

```bash
sed -i '/lxc.cgroup2.devices.allow: c 10:200/d' /etc/pve/lxc/<vmid>.conf
sed -i '/lxc.mount.entry: \/dev\/net\/tun/d' /etc/pve/lxc/<vmid>.conf
echo 'dev0: /dev/net/tun,gid=0,uid=0' >> /etc/pve/lxc/<vmid>.conf
```

---

## Tailscale

Install (run the helper, then fix TUN device as above):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/addon/add-tailscale-lxc.sh)
```

Authenticate inside the container:

```bash
# Subnet router (CT 100)
tailscale up --advertise-routes=<your-ip-range> --accept-dns=false --accept-routes=false

# DNS server (CT 101) and direct-access nodes (CT 400, CT 401)
tailscale up --accept-routes=false --accept-dns=false
```

Check status:

```bash
tailscale status
tailscale ip -4
```

---

## Docker daemon.json

Required on every Docker LXC on this network (ISP blocks Cloudflare R2 - Docker Hub's storage backend):

```json
{
  "log-driver": "journald",
  "mtu": 1450,
  "registry-mirrors": ["https://mirror.gcr.io"]
}
```

Write to `/etc/docker/daemon.json`, then `systemctl restart docker`.

---

## Komodo Periphery

Install:

```bash
curl -fsSL https://raw.githubusercontent.com/moghtech/komodo/main/scripts/setup-periphery.py | python3
```

After install, edit `/etc/systemd/system/periphery.service`:

```ini
[Service]
ExecStart=/usr/local/bin/periphery
Environment=PERIPHERY_CONFIG_PATH=/etc/komodo/periphery.config.toml
Environment=PERIPHERY_ROOT_DIRECTORY=/data/komodo   # Docker LXCs only
```

Config at `/etc/komodo/periphery.config.toml`:

```toml
[periphery]
port = 8120

[core]
addresses = ["ws://<mgmt-ip>:9120"]
```

```bash
systemctl daemon-reload && systemctl enable --now periphery
```

See [komodo](../infrastructure/komodo.md) for the full workflow.

---

## Proxmox API Tokens - Service Accounts

```bash
# Create a dedicated user
pveum user add <user>@pve --comment "<description>"

# Assign role (PVEAuditor = read-only: Sys.Audit, VM.Audit, Datastore.Audit)
pveum acl modify / --users <user>@pve --roles PVEAuditor

# Create token
pveum user token add <user>@pve <tokenid> --comment "<description>" --output-format json

# REQUIRED: disable privilege separation so the token inherits the user's permissions
# Default privsep=1 means the token has NO permissions even if the user does
pveum user token modify <user>@pve <tokenid> --privsep 0
```

---

## Proxmox API (curl)

```bash
TOKEN="PVEAPIToken=<user>@pve!<tokenid>=<token>"
BASE="https://<proxmox-ip>:8006/api2/json"

# List LXCs
curl -sk -H "Authorization: $TOKEN" "$BASE/nodes/homelab/lxc" | jq '.data[] | {vmid, name, status}'

# LXC config
curl -sk -H "Authorization: $TOKEN" "$BASE/nodes/homelab/lxc/<vmid>/config" | jq '.data'

# Node status
curl -sk -H "Authorization: $TOKEN" "$BASE/nodes/homelab/status" | jq '.data | {cpus: .cpuinfo.cpus, mem_total_gb: (.memory.total/1024/1024/1024|floor), pve: .pveversion}'

# Storage pools
curl -sk -H "Authorization: $TOKEN" "$BASE/nodes/homelab/storage" | jq -r '.data[] | "\(.storage)\t\(.type)\t\((.total//0)/1024/1024/1024|floor)GB total\t\((.used//0)/1024/1024/1024|floor)GB used"'
```

Credentials in project `.env`. Token can only be used read-only for most ops - destructive changes need the Proxmox root shell or UI.

---

## Service Users - Quick Add

When adding a new service (run on host and inside the target LXC):

```bash
# Pick next UID in range, check [user group scheme](../standards/user-group-scheme.md) for current table
useradd -u <uid> -g <primary-group-gid> -s /bin/false -d /nonexistent <name>
```

Re-run `scripts/host-users.sh` to ensure all standard users exist after any host rebuild.
