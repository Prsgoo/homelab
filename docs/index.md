# Proxmox Homelab

A single-node Proxmox VE 8 server running 11 LXC containers - media, monitoring, IoT, game servers, and personal tools. Each service group lives in its own LXC for isolation, with Docker Compose stacks managed by [Komodo](https://komo.do), Traefik for internal HTTPS, and Pi-hole + Unbound for DNS.

This site documents the full setup: the reasoning behind the architecture, step-by-step guides for each service, and operational notes from running it in production.

---

## Stack at a Glance

| CT | Role | Services |
|----|------|---------|
| management (CT 100) | Hub | Komodo, Traefik, Glance, FileBrowser, Cloudflared |
| pihole (CT 101) | DNS | Pi-hole, Unbound |
| ultrafeeder (CT 200) | ADS-B | Ultrafeeder, Piaware, FR24 |
| iot (CT 201) | IoT | Homebridge, Zigbee2MQTT, Mosquitto |
| monitoring (CT 202) | Observability | Prometheus, Grafana, Uptime Kuma |
| media-arr (CT 300) | \*arr stack | Sonarr, Radarr, Prowlarr, Bazarr, Seerr |
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
