# proxmox-homelab

Documentation and stack configs for a self-hosted homelab running on Proxmox VE 8.

**Full documentation site:** https://homelab.example.com

---

## What this is

A single-node Proxmox server running 11 LXC containers covering media, monitoring, IoT, game servers, and personal tools. Everything is managed via [Komodo](https://komo.do) with Docker Compose stacks, Traefik for reverse proxying, and Pi-hole + Unbound for DNS.

The goal of this repo is to document the full setup in enough detail that it can be rebuilt from scratch - or adapted by anyone building a similar homelab.

## Stack overview

| LXC | Role | Key services |
|-----|------|-------------|
| management (CT 100) | Infrastructure hub | Komodo, Traefik, Glance, FileBrowser, Cloudflared |
| pihole (CT 101) | DNS | Pi-hole, Unbound |
| ultrafeeder (CT 200) | ADS-B | docker-adsb-ultrafeeder, Piaware, FR24 |
| iot (CT 201) | IoT | Homebridge, Zigbee2MQTT, Mosquitto |
| monitoring (CT 202) | Observability | Prometheus, Grafana, Uptime Kuma, pve-exporter |
| media-arr (CT 300) | \*arr stack | Sonarr, Radarr, Prowlarr, Bazarr, Seerr, Dispatcharr |
| media-server (CT 301) | Media server | Jellyfin, Jellystat |
| media-dl (CT 302) | Downloads | qBittorrent, SABnzbd |
| game-panel (CT 400) | Game panel | Pterodactyl Panel |
| minecraft-wings (CT 401) | Game server | Pterodactyl Wings |
| personal-apps (CT 600) | Personal tools | Actual Budget, Mealie |

## Repo structure

```
docs/           MkDocs documentation site source
  guides/       Step-by-step setup guides per service
  wiki/         Operational reference (infrastructure, LXCs, services, standards)
  architecture.md
scripts/        Host-prep and per-CT setup scripts
stacks/         Docker Compose files organised by LXC
```

## What you'll need to adapt

- **Internal domain** - `home.example.com` throughout. Pick a subdomain you control and set up a Cloudflare DNS-01 challenge for the wildcard cert.
- **Server IPs** - `<mgmt-ip>`, `<pihole-ip>`, `<media-arr-ip>`, etc. throughout. Assign static IPs to each LXC and substitute accordingly. See [LXC Inventory](docs/wiki/lxcs/lxc-inventory.md) for the full list of placeholder names.
- **Subnet** - `<your-ip-range>` throughout. Set to match your LAN (e.g. `192.168.50.0/24`).
- **Tailscale IPs** - `<pihole-ts-ip>`, `<mgmt-ts-ip>` etc. are assigned when you join each LXC to your tailnet.
- **Admin port** - `<admin-port>` throughout. Choose any unused port for the Traefik admin entrypoint and set `ADMIN_PORT` in `scripts/.env`.
- **Data root** - `$DATA_ROOT` throughout. Set in `scripts/.env` to wherever your data disk mounts.
- **Disk devices** - `/dev/sdb1` is the default in `host-prep.sh`. Run `lsblk` and update accordingly.

## Getting started

Start with `docs/architecture.md`, then follow the guides in `docs/guides/` in dependency order (DNS → Komodo → Traefik → everything else). Each guide covers LXC creation, CT script execution, Komodo deployment, and day-2 operations.
