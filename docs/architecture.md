# Architecture

This covers the *why* behind the design decisions - the guides cover the *how*.

---

## Goals

1. **Failure isolation** - one misbehaving service shouldn't affect others
2. **Reproducible** - rebuild from scratch with the repo and documented steps
3. **Secure by default** - nothing exposed to the internet without an explicit reason
4. **Maintainable** - changes tracked in git, not clicking through UIs

---

## Container Model: LXC, Not a Single Docker Host

The common homelab approach is one machine running Docker directly, all services as containers. That works, but it has a meaningful weakness: Docker containers on the same host share a filesystem namespace and can reach each other's volumes or processes through misconfiguration or a compromised container.

LXC containers give each service group its own process namespace, network stack, and filesystem root. A runaway process in `media-dl` can't signal processes in `media-arr`. A misconfigured Docker socket mount in one CT doesn't expose the entire host. Resource limits (CPU, RAM) are enforced at the kernel cgroup level, not just in Docker's bookkeeping.

The tradeoff is operational overhead - 11 CTs to maintain instead of 1. The scripts in `scripts/` are the answer to that: each CT is set up with a single command, so the overhead is paid once on creation, not ongoing.

**Why not VMs?** Near-zero overhead vs. a full VM (shared kernel), faster startup, simpler disk passthrough. For Linux services running on a Linux host, there's no benefit to the hypervisor layer.

---

## Cross-CT File Sharing: The UID/GID Scheme

The media stack spans three CTs: `media-arr` (Sonarr, Radarr) categorizes downloads, `media-dl` (qBittorrent, SABnzbd) saves them, and `media-server` (Jellyfin) reads them. All three need read/write access to the same files on the same disk.

The standard solution is NFS. NFS adds a network path, latency, and another service to maintain. The approach here uses how LXC handles UID mapping.

In an unprivileged LXC, UIDs/GIDs inside the container map to higher UIDs on the host (Proxmox's default adds 100000). Proxmox allows overriding this for specific ranges with `lxc.idmap`. We define a `media` group with GID 1300 and tell each relevant CT to map GID 1300 → 1300 (1:1, no offset) instead of 1300 → 101300.

Result: Sonarr in CT 300 runs as GID 1300. Jellyfin in CT 301 runs as GID 1300. Both CTs map GID 1300 to host GID 1300. The host has `$DATA_ROOT/media-stack/` owned by group 1300. Both CTs can read and write it with no network layer involved.

The users and groups must exist on the Proxmox host itself (not just inside each CT) for the idmap to work.

---

## Storage Layout

Two physical disks, separated by purpose:

- **Data disk** - service configs, media library, monitoring state
- **Game disk** - game server volumes and backups only

This separation means a disk failure or runaway write on one disk can't affect the other. Game server data (large, write-heavy) is isolated from service configs and the media library.

Within the data disk, the layout follows two patterns:

- **Per-CT config directories** - one directory per LXC, bind-mounted into that CT only. Ownership is unambiguous since each directory belongs to exactly one container.
- **Shared media directory** - a single directory for the media library, bind-mounted into all three media CTs (`media-arr`, `media-server`, `media-dl`). The shared GID scheme (described above) is what makes this safe without NFS.

Adapt the exact mount points to your disk layout. The pattern matters more than the paths.

---

## IP Addressing Scheme

Each LXC gets a static IP on the LAN subnet. The scheme used here maps CT IDs to the last octet(s) of the address:

- CTs 100-202: last octet equals the CT ID (`<your-subnet>.100`, `<your-subnet>.101`, `<your-subnet>.202`, etc.)
- CTs 300+: last octet uses the last two digits of the CT ID (`300 → .30`, `400 → .40`, `600 → .60`)

The exact subnet and addresses are yours to choose. The guides reference this scheme when listing server addresses for Komodo, Prometheus scrape targets, and Traefik route backends - adapt them to match whatever you assign during LXC creation.

---

## Container Management: Why Komodo

Portainer stores compose files in its own database by default. Keeping the repo as the source of truth requires workarounds (Git integration, webhooks) that add complexity.

Komodo's `files_on_host` mode reads the compose file directly from disk at deploy time. The workflow:

1. Edit the compose in the repo
2. The file lands on the CT (via recovery scripts or manually)
3. Deploy in Komodo - it runs `docker compose up` against the file on disk

The repo is the source of truth. Komodo is the executor. Komodo also has a clean HTTP API used in the recovery scripts.

The tradeoff: Komodo is less mature than Portainer, smaller community, less documentation. If you don't need API access, Portainer is a reasonable alternative.

---

## Reverse Proxy: Traefik with DNS-01

All services are accessible at `<name>.home.example.com` over HTTPS. Traefik handles TLS via Cloudflare DNS-01 ACME: it uses a Cloudflare API token to place a `_acme-challenge` TXT record, proves domain ownership to Let's Encrypt, and gets a wildcard cert. No port 80/443 forwarding needed. The cert auto-renews.

Internal DNS is Pi-hole + Unbound. Unbound has a local zone resolving all `*.home.example.com` to the Traefik IP.

The combination gives HTTPS everywhere on the LAN with no public port exposure and fully automated cert management.

Management UIs use a Traefik middleware that only allows requests from Tailscale IP ranges - the restriction is at the proxy layer, regardless of whether the service itself has auth.

---

## Remote Access: Tailscale + Cloudflare Tunnel

**Tailscale** is for personal access from trusted devices. CT 100 advertises the internal LAN as a Tailscale route - any Tailscale device can reach the full `<your-ip-range>` subnet. Pi-hole is set as the Tailscale DNS nameserver so `*.home.example.com` resolves correctly on remote devices.

**Cloudflare Tunnel** is for services that need to be publicly reachable. The tunnel runs in CT 100 - no inbound ports needed on the router. Currently used for Pterodactyl Panel so Wings nodes can reach it externally.

Internal-only services (Komodo, Grafana, Jellyfin) are not exposed via Cloudflare Tunnel - Tailscale is sufficient.

---

## What's Deliberately Not Here

**Kubernetes** - Single node. The operational surface area of a K8s cluster isn't justified for this scale.

**ZFS** - ext4 on both data disks. ZFS snapshots would be useful but the memory overhead and complexity aren't worth it at single-node homelab scale.

**NFS** - Bind mounts with idmap handle cross-CT file sharing without introducing a network dependency or another service to maintain.

---

## Tensions Worth Acknowledging

**LXC vs. containers-only vs. native-only** - Three realistic options here:

1. *Single Docker host* - all services as containers on one machine. Simplest operationally, but no process namespace isolation between services. A bad Docker socket mount or runaway container affects everything.
2. *Docker-in-LXC per group* - what this setup does. Each service group gets its own LXC (and thus its own filesystem root and network stack), but services within a group still run as Docker containers. The UID/GID idmap scheme for cross-CT file sharing only works this way - separate containers with separate idmap configs.
3. *Native installs in LXC, no Docker* - one LXC per service or service group, each running the service directly (systemd units, apt packages). Maximum isolation, no Docker overhead, but every service needs its own LXC lifecycle and dependency management.

Option 2 hits a good tradeoff: LXC isolation where it matters (between unrelated services), Docker ergonomics where it's useful (compose files, image updates, Komodo management). The cross-CT file sharing requirement is what rules out option 1.

**Traefik vs. nginx-proxy-manager** - Traefik is config-as-code and integrates cleanly with Let's Encrypt DNS-01. NPM has a friendlier UI and would be faster to get running. Traefik's middleware composition (Tailscale IP allowlisting) is the deciding factor.

**Komodo vs. Portainer** - Komodo's API and `files_on_host` behavior are better fits for automation. Portainer has a larger community and more documentation. Either works; API access is what made Komodo the choice here.
