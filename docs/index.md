# Proxmox Homelab

**Linux** · **Proxmox VE / LXC** · **Docker** · **reverse proxy (Traefik v3)** · **monitoring (Prometheus + Grafana)** · **DNS (Pi-hole + Unbound)** · **VPN (Tailscale)** · **IoT (Zigbee, MQTT, HomeKit)** · **deployment automation** · **TLS (DNS-01 ACME)**

A single-node Proxmox VE 8 server running 11 LXC containers. Each service group lives in its own container for isolation, with Docker Compose stacks managed by [Komodo](https://komo.do), Traefik handling internal HTTPS, and Pi-hole + Unbound for DNS.

---

## What this demonstrates

| Capability | Detail |
|---|---|
| **Linux / LXC** | 11 Debian 13 containers; cross-CT file sharing via UID/GID idmap (no NFS) |
| **Docker** | 14 Compose stacks managed by Komodo - API-driven, repo as source of truth |
| **Reverse proxy** | Traefik v3 with DNS-01 ACME wildcard cert; three IP-allowlist middleware tiers |
| **Monitoring** | Prometheus (30d retention) + Grafana + pve-exporter + node-exporter on every LXC |
| **DNS** | Pi-hole + Unbound recursive resolver; local zone for internal domain; works over Tailscale |
| **VPN** | Tailscale on 4 LXCs; CT 100 advertises LAN subnet as a route |
| **Security** | No public exposure; wildcard TLS via DNS-01; Traefik IP-allowlist for management tier |
| **IoT** | Homebridge + Zigbee2MQTT + Mosquitto; USB device passthrough via udev |
| **Deployment automation** | 12 idempotent per-CT setup scripts sharing a common helper library |
| **Disaster recovery** | Documented 10-phase rebuild procedure; ~3-4h from bare hardware |

**Not implemented:** automated backups - single-node hardware constraint (no second node or off-site target to ship to).

---

## Stack at a Glance

| CT | Role | Services |
|----|------|---------|
| management (CT 100) | Hub | Komodo, Traefik, Glance, FileBrowser |
| pihole (CT 101) | DNS | Pi-hole, Unbound |
| ultrafeeder (CT 200) | ADS-B | Ultrafeeder, Piaware, FR24, OpenSky |
| iot (CT 201) | IoT | Homebridge, Zigbee2MQTT, Mosquitto |
| monitoring (CT 202) | Observability | Prometheus, Grafana, Uptime Kuma, pve-exporter |
| media-arr (CT 300) | *arr stack | Sonarr, Radarr, Prowlarr, Bazarr, Seerr, Dispatcharr, Recyclarr, Unpackerr |
| media-server (CT 301) | Media server | Jellyfin, Jellystat |
| media-dl (CT 302) | Downloads | qBittorrent, SABnzbd |
| game-panel (CT 400) | Panel | Pterodactyl Panel |
| minecraft-wings (CT 401) | Game server | Pterodactyl Wings |
| personal-apps (CT 600) | Personal tools | Actual Budget, Mealie |

---

## Where to Start

**New to this setup?** Read Architecture first - it explains the design decisions before you touch anything.

[Architecture](architecture.md){ .md-button .md-button--primary }
[Guides Overview](guides/index.md){ .md-button }
[Reference](wiki/_master-index.md){ .md-button }

### Recommended reading order

1. [Architecture](architecture.md) - why LXC, how cross-CT file sharing works without NFS, why Komodo
2. [DNS (Pi-hole + Unbound)](guides/pihole.md) - everything depends on internal DNS
3. [Container Manager (Komodo)](guides/komodo.md) - manages all Docker stacks
4. [Reverse Proxy (Traefik)](guides/traefik.md) - HTTPS for every service
5. Everything else in any order

Config files, Docker Compose stacks, and CT setup scripts live in the [GitHub repository](https://github.com/Prsgoo/homelab).
