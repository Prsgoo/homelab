# Container Manager - Komodo

## What you'll end up with

Komodo Core running in CT 100 alongside MongoDB and a local Periphery agent (all as Docker containers). Every other Docker LXC will run the Periphery binary agent and appear as a managed server in Komodo. Stacks are deployed in "files on host" mode - the git repo is the source of truth, Komodo is the executor.

---

## Prerequisites

- Proxmox host set up and reachable
- Pi-hole running and internal DNS working (`*.home.example.com` resolving to `<mgmt-ip>`)
- The repo cloned on the Proxmox host at `/opt/proxmox-admin`
- `scripts/.env` filled in (Komodo secrets, KOMODO_CORE_ADDR)

---

## 1. Create the LXC

CT 100 runs Docker, so use the Docker community helper:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/docker.sh)
```

| Setting | Value |
|---------|-------|
| CT ID | 100 |
| Hostname | management |
| Cores | 2 |
| RAM | 2048 MB |
| Disk | 8 GB |
| IP | <mgmt-ip>/24 |
| Gateway | <gateway-ip> |

---

## 2. Run the CT script

```bash
cd /opt/proxmox-admin
bash scripts/ct100-management.sh
```

This handles everything that needs root on the Proxmox host before Komodo boots:

- Sets ACLs on `$DATA_ROOT` so CT 100 can traverse it
- Applies bind mounts (full data disk + minecraft pool)
- Adds the TUN device entry for Tailscale
- Pre-deploys compose files and `.env` files for all management stacks (cloudflared, filebrowser, glance, traefik, node-exporter)

CT 100 is **not started** by this script - Komodo is the first thing to boot in it manually.

---

## 3. Configure the Docker daemon

Start CT 100, then configure Docker before doing anything else:

```bash
pct start 100
pct exec 100 -- bash -c 'cat > /etc/docker/daemon.json << EOF
{
  "log-driver": "journald",
  "mtu": 1450,
  "userland-proxy": false
}
EOF
systemctl restart docker'
```

!!! warning "`userland-proxy: false` is required"
    Without this, Docker proxies all connections through the bridge gateway, masking real client IPs. This breaks Traefik's IP-based middleware (used to restrict admin tools to Tailscale-only access). Set it now before deploying anything.

The MTU of 1450 prevents fragmentation issues common with some ISPs.

---

## 4. Bootstrap Komodo Core

Komodo bootstraps itself - you run the compose manually once, and after that Komodo manages everything.

**4.1** Copy the bootstrap compose into CT 100:

```bash
pct exec 100 -- mkdir -p /opt/komodo
pct push 100 stacks/management/komodo/compose.yaml /opt/komodo/compose.yaml
pct push 100 stacks/management/komodo/compose.env.example /opt/komodo/compose.env
```

**4.2** Fill in the secrets. The values are in `scripts/.env`:

```bash
pct exec 100 -- nano /opt/komodo/compose.env
```

Required values:

| Variable | Description |
|----------|-------------|
| `KOMODO_HOST` | `http://<mgmt-ip>:9120` |
| `KOMODO_INIT_ADMIN_PASSWORD` | First admin password (change after login) |
| `KOMODO_DATABASE_USERNAME` | MongoDB username |
| `KOMODO_DATABASE_PASSWORD` | MongoDB password (strong random string) |
| `KOMODO_WEBHOOK_SECRET` | For Git webhooks (random string) |
| `KOMODO_JWT_SECRET` | JWT signing key (random string, 32+ chars) |

**4.3** Start Komodo:

```bash
pct exec 100 -- bash -c 'cd /opt/komodo && docker compose --env-file compose.env -f compose.yaml up -d'
```

**4.4** Wait about 30 seconds, then open `http://<mgmt-ip>:9120` and create the admin account using the password you set in `compose.env`.

---

## 5. Add servers

Go to **Settings → Servers → Add Server** for each LXC. Periphery was installed on all of them by the CT scripts - they'll turn green within ~30 seconds of being added.

Add each server using `wss://<ct-ip>:8120` as the address. The IP addressing scheme is explained in [Architecture](../architecture.md#ip-addressing-scheme) - adapt to whatever you assigned during LXC creation.

!!! note "Enable after adding"
    Servers created via the API or UI start as `enabled: false`. Click the toggle to enable each one after adding.

---

## 6. Deploy your first stack

With servers connected, deploy the management stacks. Start with Traefik (see the [Traefik guide](traefik.md)), then the rest.

The CT script already placed compose files and `.env` files in each stack directory. In Komodo, create each stack pointing to those existing files:

1. **Stacks → Add Stack**
2. Set the server, stack name, and directory (e.g. `stacks/traefik`)
3. Enable **Files on Host**
4. Click **Deploy**

See the [Traefik guide](traefik.md) for the first deploy in detail.

---

## 7. Add a Traefik route (after Traefik is running)

Once Traefik is deployed, Komodo's UI is accessible at `https://komodo.home.example.com:<admin-port>`.

The route file is already in the repo at `stacks/management/traefik/config/`. No DNS or cert changes needed - the wildcard covers it automatically.

---

## Day-2 operations

### Updating Komodo

```bash
pct exec 100 -- bash -c 'cd /opt/komodo && docker compose pull && docker compose --env-file compose.env -f compose.yaml up -d'
```

### Updating a stack

In Komodo UI: **Stacks → [stack name] → Deploy**. Komodo pulls the latest image and restarts the container.

### Checking Periphery connectivity

Servers → click any server → the status indicator shows green (connected), yellow (connecting), or red (unreachable). Red usually means the Periphery service on that CT needs a restart:

```bash
pct exec <vmid> -- systemctl restart periphery
```

### Adding a new server

Run the CT script for the new LXC (installs Periphery), then add it in Komodo Settings → Servers.

---

## Troubleshooting

**Server stays red after adding**

1. Confirm Periphery is running: `pct exec <vmid> -- systemctl status periphery`
2. Check the Komodo Core address in Periphery's config matches what you used in Komodo UI: `pct exec <vmid> -- cat /etc/komodo/periphery.config.toml`
3. Confirm the CT is reachable on port 8120: `curl -k https://<server-ip>:8120` from CT 100

**Komodo UI not loading after reboot**

```bash
pct exec 100 -- bash -c 'cd /opt/komodo && docker compose --env-file compose.env -f compose.yaml up -d'
```

Komodo doesn't have a systemd unit - it needs to be started manually after CT 100 reboots, unless you add one.

**"Public key invalid" / NotOk status on a server**

Usually a Core/Periphery version mismatch. Reinstall Periphery on the affected CT matching the Core version:

```bash
curl -fsSL https://raw.githubusercontent.com/moghtech/komodo/main/scripts/setup-periphery.py \
  | python3 - --version v<core-version>
```
