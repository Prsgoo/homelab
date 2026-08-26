# proxmox-homelab

**Linux** · **Proxmox VE / LXC** · **Docker** · **reverse proxy (Traefik v3)** · **monitoring (Prometheus + Grafana)** · **DNS (Pi-hole + Unbound)** · **VPN (Tailscale)** · **IoT (Zigbee, MQTT, HomeKit)** · **deployment automation** · **TLS (DNS-01 ACME)**

**Not implemented here:** automated backups

---

Documentation and stack configs for a self-hosted homelab running on Proxmox VE 8.

**Full documentation site:** https://homelab.prsgoo.com

---

## What this demonstrates

### Linux
All 11 containers run Debian 13 under Proxmox VE 8. Cross-container file sharing uses Linux UID/GID idmap at the LXC layer rather than NFS - each container maps its internal user to a shared GID on the host, giving the media stack shared read/write access to a single data disk without a network filesystem.

### Proxmox VE / LXC containers
Services are split across 11 LXC containers rather than a single Docker host. Each container is scoped to a service group (media, monitoring, IoT, etc.) with separate namespaces and resource limits. This is a deliberate isolation choice over the simpler "one big Docker host" approach.

### Docker
14 Docker Compose stacks deployed across the LXC fleet. All stacks are managed through [Komodo](https://komo.do) - an API-driven stack manager that treats the repo as source of truth. Deploying a stack change is a pull-and-restart operation triggered through Komodo's API, not SSH.

### Reverse proxy (Traefik v3)
Traefik handles all internal HTTPS with a wildcard cert for `*.home.<your-domain>` issued via DNS-01 ACME challenge against Cloudflare. No port forwarding required - all certs are issued and renewed automatically. Services expose Traefik labels in their compose files; routes are dynamic. Three middleware tiers enforce access:
- `admin-only` - Tailscale IP allowlist, management UIs only
- `streaming-shared` - Jellyfin accessible to non-admin Tailscale devices
- `minecraft-shared` - game panel accessible to game server users

### Monitoring and observability
- **Prometheus** scrapes pve-exporter (Proxmox cluster metrics), node-exporter (deployed to every LXC), and ultrafeeder (ADS-B metrics). 30-day retention.
- **Grafana** for dashboards, wired to Prometheus.
- **Uptime Kuma** for uptime monitoring and a status page.
- **pve-exporter** exposes Proxmox VE API metrics to Prometheus.

### DNS
Pi-hole handles ad blocking and LAN-wide DNS. Unbound runs as a recursive resolver (no upstream forwarder) with a local zone override that resolves `*.home.<your-domain>` to the management container's IP. Tailscale clients are set to use Pi-hole as their DNS server, so ad blocking and local resolution work over VPN too.

### VPN and remote access
Tailscale is installed on 4 containers. The management container advertises the LAN subnet (`192.168.50.0/24`) as a Tailscale route, making all internal services reachable over VPN without per-service port exposure. Traefik's IP allowlist middleware enforces that management UIs are only accessible from known Tailscale device IPs.

### Security
No services are exposed to the public internet. The architecture is Tailscale-only for all access:
- Wildcard TLS via DNS-01 (no HTTP-01, no port 80/443 open to internet)
- Traefik IP allowlist middleware for management tier
- Cloudflare Tunnel stack is configured and ready for selective public exposure - current access is Tailscale-only, but any service can be published without touching the firewall

### Deployment automation
12 idempotent Bash scripts (one per LXC) handle CT configuration: group/user creation, bind mounts, idmap patching, Periphery agent install. A shared `common.sh` provides helpers used across all scripts. Running a script twice produces the same result. The host-prep script handles storage pool creation, mount points, and udev rules for USB device passthrough.

### IoT
- **Homebridge** bridges HomeKit to non-native devices
- **Zigbee2MQTT** + **Mosquitto** for Zigbee device management via MQTT
- **USB device passthrough** from Proxmox host to the IoT LXC via udev rule (SiLabs CP210x Zigbee coordinator)

### Disaster recovery
The full rebuild procedure is documented in `docs/wiki/ops/disaster-recovery.md` - 10 phases covering Proxmox reinstall, storage remount, LXC recreation, and service restoration. Estimated rebuild time from bare hardware: 3-4 hours. The assumption is that the data disk survives; the OS disk is treated as throwaway.

---

## What's not here

**Automated backups** - not possible on a single-node setup without a second node or remote storage target to ship backups to. The disaster recovery strategy assumes the data disk survives host failure and documents how to rebuild everything else from scratch. This is a hardware constraint, not an oversight - adding a second node or off-site target would unblock it.

---

## Stack overview

| LXC | Role | Key services |
|-----|------|-------------|
| management (CT 100) | Infrastructure hub | Komodo, Traefik, Glance, FileBrowser |
| pihole (CT 101) | DNS | Pi-hole, Unbound |
| ultrafeeder (CT 200) | ADS-B | docker-adsb-ultrafeeder, Piaware, FR24, OpenSky |
| iot (CT 201) | IoT | Homebridge, Zigbee2MQTT, Mosquitto |
| monitoring (CT 202) | Observability | Prometheus, Grafana, Uptime Kuma, pve-exporter |
| media-arr (CT 300) | *arr stack | Sonarr, Radarr, Prowlarr, Bazarr, Seerr, Dispatcharr, Recyclarr |
| media-server (CT 301) | Media server | Jellyfin, Jellystat |
| media-dl (CT 302) | Downloads | qBittorrent, SABnzbd |
| game-panel (CT 400) | Game panel | Pterodactyl Panel |
| minecraft-wings (CT 401) | Game server | Pterodactyl Wings |
| personal-apps (CT 600) | Personal tools | Actual Budget, Mealie |

---

## Repo structure

```
docs/           MkDocs documentation site source
  guides/       Step-by-step setup guides (dependency-ordered: DNS → Komodo → Traefik → ...)
  wiki/         Operational reference (infrastructure, LXCs, services, standards, ops)
  architecture.md
scripts/        Host-prep and per-CT setup scripts (idempotent)
stacks/         Docker Compose files organised by LXC
```

---

## What you'll need to adapt

- **Internal domain** - `home.example.com` throughout. Pick a subdomain you control and set up a Cloudflare DNS-01 challenge for the wildcard cert.
- **Server IPs** - `<mgmt-ip>`, `<pihole-ip>`, `<media-arr-ip>`, etc. throughout. Assign static IPs to each LXC and substitute accordingly. See [LXC Inventory](docs/wiki/lxcs/lxc-inventory.md) for the full list.
- **Subnet** - `<your-ip-range>` throughout. Set to match your LAN (e.g. `192.168.50.0/24`).
- **Tailscale IPs** - `<pihole-ts-ip>`, `<mgmt-ts-ip>` etc. are assigned when you join each LXC to your tailnet.
- **Admin port** - `<admin-port>` throughout. Choose any unused port for the Traefik admin entrypoint and set `ADMIN_PORT` in `scripts/.env`.
- **Data root** - `$DATA_ROOT` throughout. Set in `scripts/.env` to wherever your data disk mounts.
- **Disk devices** - `/dev/sdb1` is the default in `host-prep.sh`. Run `lsblk` and update accordingly.

## Getting started

Start with `docs/architecture.md` for the design rationale, then follow the guides in `docs/guides/` in dependency order (DNS → Komodo → Traefik → everything else). Each guide covers LXC creation, CT script execution, Komodo deployment, and day-2 operations.
