# Guides

Each guide covers the full setup of a service: install, first-run configuration, integration with the rest of the stack, and day-2 operations. Not just "run this command" but everything you'd need to actually have it working.

## Order matters

The guides follow dependency order. Pi-hole provides DNS for everything. Traefik provides HTTPS for everything. Komodo manages all the Docker stacks. Set those up first.

| # | Guide | Depends on |
|---|-------|-----------|
| 1 | [DNS (Pi-hole + Unbound)](pihole.md) | Nothing |
| 2 | [Container Manager (Komodo)](komodo.md) | Pi-hole (for internal domain resolution) |
| 3 | [Reverse Proxy (Traefik)](traefik.md) | Komodo (Traefik is a stack deployed via Komodo) |
| 4 | [Remote Access (Tailscale)](tailscale.md) | Pi-hole (as Tailscale DNS) |
| 5 | [External Access (Cloudflare Tunnel)](cloudflare-tunnel.md) | Traefik |
| 6 | [Media Stack](media-stack.md) | Komodo, Traefik |
| 7 | [Monitoring](monitoring.md) | Komodo, Traefik |
| 8 | [IoT (Homebridge + Zigbee)](iot.md) | Komodo, Traefik |
| 9 | [ADS-B (Ultrafeeder)](ultrafeeder.md) | Komodo |
| 10 | [Game Servers (Pterodactyl)](pterodactyl.md) | Tailscale, Cloudflare Tunnel |

## Guide structure

Every guide follows the same format:

- **What you'll end up with** - the goal state
- **Prerequisites** - what must be running first
- **LXC setup** - container creation and CT script
- **Install** - service installation
- **Configuration** - first-run setup inside the application
- **Integration** - connecting to Traefik, DNS, monitoring, other services
- **Verify** - explicit checks to confirm everything is working
- **Day-2 operations** - updates, common tasks, maintenance
- **Troubleshooting** - failures actually encountered and how to fix them
