---
title: Management LXC (CT 100)
updated: 2026-08-05
---

# Management LXC (CT 100)

Central management node. Runs Traefik, Komodo Core, Glance, FileBrowser, and Tailscale subnet router.

## Specs

| Setting | Value |
|---------|-------|
| CT ID | 100 |
| Hostname | management |
| Template | Debian 13 standard |
| rootfs | 8GB |
| RAM | 2048MB |
| Cores | 2 |
| IP | <mgmt-ip> |
| onboot | yes |
| Unprivileged | yes |
| Features | nesting=1, keyctl=1 |

## Bind Mounts

| Mount | Host Path | Container Path |
|-------|-----------|---------------|
| mp0 | `$DATA_ROOT` | `/data` |
| mp1 | `$DATA_ROOT/minecraft` | `/minecraft` |

mp0 gives containers access to the full data pool. mp1 makes the minecraft pool available to FileBrowser.

## idmap

Not required - all services run under Docker's root UID; no per-service UID scheme.

## Docker Configuration

`/etc/docker/daemon.json`:

```json
{
  "log-driver": "journald",
  "mtu": 1450,
  "registry-mirrors": ["https://mirror.gcr.io"],
  "userland-proxy": false
}
```

`userland-proxy: false` is required - Docker's default proxy masquerades all source IPs to the bridge gateway, breaking Traefik's `ipAllowList` middleware.

Registry mirror and MTU 1450 required: ISP blocks Cloudflare R2 (Docker Hub's storage backend).

## Bind Mount Ownership

CT 100's container root (UID 0) maps to host UID 100000. Set ACLs on the data pool root:

```bash
setfacl -m u:100000:rx $DATA_ROOT
setfacl -m u:100000:rx $DATA_ROOT/config
chown -R 100000:100000 $DATA_ROOT/config/management
```

Any new top-level directory under `$DATA_ROOT/` also needs an explicit ACL - parent ACLs don't propagate:

```bash
setfacl -Rm u:100000:rwx $DATA_ROOT/<new-dir>
setfacl -Rdm u:100000:rwx $DATA_ROOT/<new-dir>
```

## Komodo

CT 100 runs Komodo Core itself - the "Local" server in Komodo. Periphery is a Docker container inside the Komodo compose (not a binary agent).

| Setting | Value |
|---------|-------|
| Compose | `/opt/komodo/compose.yaml` |
| Env file | `/opt/komodo/compose.env` |

See [komodo core](../services/management/komodo-core.md).

## Tailscale

Subnet router advertising `<your-ip-range>`.

| Setting | Value |
|---------|-------|
| Tailscale IP | <mgmt-ts-ip> |
| Flags | `--advertise-routes=<your-ip-range> --accept-dns=false --accept-routes=false` |

TUN device entry in `/etc/pve/lxc/100.conf`:
```
dev0: /dev/net/tun,gid=0,uid=0
```

See [tailscale](../infrastructure/tailscale.md).

## Services

→ [management](../services/management/_index.md) - Komodo Core, Traefik, Glance, FileBrowser
