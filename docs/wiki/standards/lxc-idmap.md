---
title: Proxmox Unprivileged LXC - UID/GID Mapping
updated: 2026-05-08
---

# Proxmox Unprivileged LXC - UID/GID Mapping

## Why This Exists

Unprivileged LXCs run inside a Linux user namespace. UIDs and GIDs inside the container are remapped to different (higher) UIDs on the host. This isolates the container - even if a process escapes the container as "root" (UID 0), it's only UID 100000 on the host, which has no special privileges.

Proxmox's default mapping shifts all container UIDs/GIDs by +100000:

```
Container UID/GID  →  Host UID/GID
0  (root)          →  100000
1000               →  101000
1001               →  101001
1200               →  101200
```

---

## How This Breaks Bind Mounts

When you bind-mount a host directory into an unprivileged LXC, the files on the host keep their host UIDs. The container sees them remapped through its namespace.

Example without a fix:
- Host file: `$DATA_ROOT/iot/homebridge/` owned by host UID 1200
- Inside container: appears owned by UID 4294967295 (unmapped - no access)

Or the reverse:
- You create the host directory owned by UID 1200 (`homebridge`)
- Inside the container, the service running as UID 1200 sees it owned by UID 4294967295

Either way, the service cannot read or write its own config directory.

---

## The Fix - lxc.idmap Overrides

Proxmox lets you override the mapping for specific UID/GID ranges. For any range you declare a 1:1 mapping (container UID X → host UID X), files owned by those UIDs on the host appear with the same UID inside the container.

### Standard idmap block for this homelab

This block maps our service UID/GID range (1000–1499) 1:1, and everything else with the standard +100000 offset.

```
# UIDs
lxc.idmap: u 0 100000 1000       # container 0–999    → host 100000–100999
lxc.idmap: u 1000 1000 500       # container 1000–1499 → host 1000–1499 (1:1)
lxc.idmap: u 1500 101500 64036   # container 1500+     → host 101500+

# GIDs
lxc.idmap: g 0 100000 1000       # container 0–999    → host 100000–100999
lxc.idmap: g 1000 1000 500       # container 1000–1499 → host 1000–1499 (1:1)
lxc.idmap: g 1500 101500 64036   # container 1500+     → host 101500+
```

The three ranges must cover all 65536 UIDs: 1000 + 500 + 64036 = 65536 ✓

---

## Bind Mount Root Ownership - Critical Pattern

The bind mount **root** directory (what appears as `/data/` inside the container) must be traversable by service users. If it's owned by `100000:100000` (container root) with mode 750, service users hit `---` on the parent and get permission denied before reaching their own subdirectory.

**Correct pattern for every bind mount root:**

```bash
# On Proxmox host - bind mount root
chown 100000:<service-group-gid> $DATA_ROOT/<lxc-name>/
chmod 750 $DATA_ROOT/<lxc-name>/

# Service subdirectory
chown <uid>:<service-group-gid> $DATA_ROOT/<lxc-name>/<service>/
chmod 750 $DATA_ROOT/<lxc-name>/<service>/
```

Example for docker-iot:
```bash
chown 100000:1200 $DATA_ROOT/config/iot/     # root owns it, iot group (GID 1200) can traverse
chmod 750 $DATA_ROOT/config/iot/
chown 1200:1200 $DATA_ROOT/config/iot/homebridge/
chmod 750 $DATA_ROOT/config/iot/homebridge/
chown 1201:1200 $DATA_ROOT/config/iot/zigbee2mqtt/
chmod 750 $DATA_ROOT/config/iot/zigbee2mqtt/
chown 1202:1200 $DATA_ROOT/config/iot/mosquitto/
chmod 750 $DATA_ROOT/config/iot/mosquitto/
```

**ACL inheritance warning:** The DATA pool directories may have default Proxmox ACLs that propagate into new subdirectories. If a service can't write despite correct ownership, check with `getfacl` and strip with `setfacl -b <path>` if needed.

---

## Host-Side Requirements

The 1:1 mapping requires the users and groups to exist on the **Proxmox host itself**, not just inside the LXC. Otherwise the host filesystem doesn't know what to call UID 1200 when displaying file ownership, and you can't set ownership by name.

### Host-side users and groups

Groups use the same base as their domain's UID range (iot UIDs start at 1200 → GID 1200, etc.).

```bash
# Shared groups
groupadd -g 1200 iot
groupadd -g 1300 media
groupadd -g 1400 gaming

# IoT & monitoring (1200–1299)
useradd -u 1200 -g 1200 -s /bin/false -d /nonexistent homebridge
useradd -u 1201 -g 1200 -s /bin/false -d /nonexistent zigbee2mqtt
useradd -u 1202 -g 1200 -s /bin/false -d /nonexistent mosquitto
useradd -u 1210 -s /bin/false -d /nonexistent ultrafeeder   # private group

# Media (1300–1399)
useradd -u 1300 -g 1300 -s /bin/false -d /nonexistent sonarr
useradd -u 1301 -g 1300 -s /bin/false -d /nonexistent radarr
useradd -u 1302 -g 1300 -s /bin/false -d /nonexistent prowlarr
useradd -u 1303 -g 1300 -s /bin/false -d /nonexistent bazarr
useradd -u 1305 -g 1300 -s /bin/false -d /nonexistent unpackerr
useradd -u 1306 -g 1300 -s /bin/false -d /nonexistent recyclarr
useradd -u 1310 -g 1300 -s /bin/false -d /nonexistent jellyfin
useradd -u 1320 -g 1300 -s /bin/false -d /nonexistent qbittorrent
```

Add new rows here as new services are added (see [user group scheme](user-group-scheme.md)).

---

## Applying to a New LXC

The idmap block must be added to the LXC config file on the host **before first start**. The Proxmox API token cannot set this - it requires root.

In the Proxmox root shell:
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

Also add the `userns` feature flag to allow the override (if not already present):
```bash
# In the LXC config or via: pct set <vmid> -features keyctl=1,nesting=1
```

---

## Which LXCs Need This

| LXC type | Needs idmap? | Reason |
|----------|-------------|--------|
| Management (100-range) | No | Runs as root, no service-owned bind mounts |
| game-panel (400-range) | No | Runs native services (Apache, MariaDB) as system users; bind mounts owned by container root or system users, not service UIDs 1000–1499 |
| minecraft-wings (400-range) | No | Wings runs as root; bind mounts owned by container root (host UID 100000) |
| docker-iot (200-range) | Yes | Service users own config dirs on $DATA_ROOT |
| ultrafeeder (200-range) | Yes | Service user owns data dir on $DATA_ROOT |
| media-lxc (300-range) | Yes | Service users own config dirs, shared media |

**Rule:** any LXC with a bind mount where a non-root service user needs write access → add the idmap block.

---

## Verifying It Works

After starting a container with the idmap block, check that file ownership resolves correctly:

Inside the container:
```bash
ls -la /data/          # should show homebridge, zigbee2mqtt, mosquitto as owners
```

On the host:
```bash
ls -la $DATA_ROOT/iot/  # should show the same UIDs - no 4294967295
stat $DATA_ROOT/iot/homebridge/  # Uid should be 1200
```

---

## USB / Serial Device Passthrough

**Use Proxmox native `dev` config - not `lxc.mount.entry`.**

The combination of `lxc.cgroup2.devices.allow` + `lxc.mount.entry` does NOT properly set up the cgroup device allowlist in practice. Even root inside the LXC gets "permission denied" opening the device, and Docker containers cannot access it regardless of `device_cgroup_rules` or `privileged` mode.

The correct approach:
```
dev0: /dev/ttyUSB0,gid=<gid>,uid=0
```

Proxmox handles both the device node creation and cgroup allowlist automatically. The `gid` parameter sets group ownership inside the LXC - use the service group GID (e.g. `gid=1200` for iot services).

With `dev0` set correctly, Docker containers can use `devices: - /dev/ttyUSB0:/dev/ttyUSB0` in compose without needing `privileged: true`.

**Also applies to the TUN device for Tailscale.** The Proxmox Helper Script (`add-tailscale-lxc.sh`) adds `lxc.cgroup2.devices.allow: c 10:200 rwm` + `lxc.mount.entry: /dev/net/tun ...` - this fails for the same reason. Fix:
1. Remove those two lines from `/etc/pve/lxc/<vmid>.conf`
2. Add `dev0: /dev/net/tun,gid=0,uid=0`

---

## Key Takeaways

- All LXCs with service-owned bind mounts need the idmap block in their config
- The idmap block must be added via the Proxmox root shell - the API token cannot do it
- Service users must exist on the **host** as well as inside the LXC - see [user group scheme](user-group-scheme.md)
- Shared group GIDs match their domain's UID range base: iot=1200, media=1300, gaming=1400
- Management LXC is exempt - it's root-based with no service-owned bind mounts
- USB/serial device passthrough: always use Proxmox `dev0` config, never `lxc.mount.entry`
