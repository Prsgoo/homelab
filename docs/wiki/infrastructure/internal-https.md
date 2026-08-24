---
title: Internal HTTPS (home.example.com)
updated: 2026-07-02
---

# Internal HTTPS (home.example.com)

Every internal service is reachable at `<service>.home.example.com` (HTTPS, real Let's Encrypt cert) - user-facing services on `:443`, admin tools on `:<admin-port>`. This is the **only** URL scheme: the old `<service>.homelab` (HTTP) was retired 2026-07-02.

## Architecture

```
Client (LAN/Tailscale) → Unbound (CT 101) redirects *.home.example.com → <mgmt-ip>
                        → Traefik (CT 100) :443, wildcard cert *.home.example.com
```

- `*.home.example.com` resolves **only inside the network** - no public DNS record exists for it
- Traefik holds a real wildcard cert for `home.example.com` + `*.home.example.com`, obtained via Cloudflare DNS-01 challenge (TXT-only validation, no public exposure needed)
- `.homelab` (HTTP, port 80) has been **retired** (2026-07-02) - `.home.example.com` is the only scheme

## DNS - CT 101 (Unbound)

`local-zone redirect` pattern in Unbound (see [pihole](../lxcs/pihole.md)), file `/etc/unbound/unbound.conf.d/home-internal.conf`:
```
server:
    local-zone: "home.example.com." redirect
    local-data: "home.example.com. A <mgmt-ip>"
```
`systemctl restart unbound` after creating. Pi-hole forwards `*.home.example.com` to Unbound (it's a real domain with no local record) - Unbound's redirect answers before any recursive lookup.

## Traefik - CT 100

### Static config additions
`websecure` entrypoint (`:443`) already existed. Added `certificatesResolvers`:
```yaml
certificatesResolvers:
  cloudflare:
    acme:
      email: admin@example.com
      storage: /etc/traefik/acme/acme.json
      dnsChallenge:
        provider: cloudflare
        resolvers:
          - "1.1.1.1:53"
          - "8.8.8.8:53"
```

### Cloudflare API token
Scoped token (`Zone:DNS:Edit` + `Zone:Zone:Read` on `example.com`), stored as a Komodo stack env var on the `traefik` stack:
```
CLOUDFLARE_DNS_API_TOKEN=<token>
```
Must also be referenced in `compose.yaml` - Komodo stack env vars are not auto-injected into the container:
```yaml
    environment:
      - CLOUDFLARE_DNS_API_TOKEN=${CLOUDFLARE_DNS_API_TOKEN}
```

### acme.json setup
Must exist **before** first start as an empty JSON file with `600` permissions:
```bash
echo '{}' > /data/config/management/traefik/acme/acme.json
chmod 600 /data/config/management/traefik/acme/acme.json
```

### Wildcard cert request
One router requests the wildcard; all others reuse it from the cert store. Defined on the `traefik-tls` router in `stacks/management/traefik/traefik-route.yml`:
```yaml
    traefik-tls:
      rule: "Host(`traefik.home.example.com`)"
      service: traefik-dashboard
      entryPoints:
        - websecure
      tls:
        certResolver: cloudflare
        domains:
          - main: "home.example.com"
            sans:
              - "*.home.example.com"
```

## Per-service routes

Each service has a single `.home.example.com` router - `entryPoints: [websecure]` (443, user-facing) or `[admin]` (8443, admin tools), `Host(<name>.home.example.com)`, `tls: {}` (no cert resolver needed, reuses the cached wildcard). Applied to all routes in [management lxc](../lxcs/management-lxc.md)'s Traefik table, plus per-LXC route tables ([media arr](../lxcs/media-arr.md), [media dl](../lxcs/media-dl.md), [media server](../lxcs/media-server.md), [game panel](../lxcs/game-panel.md), [monitoring](../lxcs/monitoring.md)).

## Adding a new service

Add one router: `Host(<name>.home.example.com)`, `tls: {}`, and `entryPoints: [websecure]` (443, user-facing) or `[admin]` + `admin-only` middleware (8443, admin tools) - no DNS or cert changes needed, the wildcard already covers it. Do **not** add a `web`/:80 `.homelab` router (retired).

## Key Takeaways

- `*.home.example.com` is internal-only - no public DNS record, resolved via Unbound redirect on CT 101
- Wildcard Let's Encrypt cert obtained once via Cloudflare DNS-01 - covers all current and future `*.home.example.com` subdomains automatically
- This Traefik version's lego Cloudflare provider expects `CLOUDFLARE_DNS_API_TOKEN` (not the older `CF_DNS_API_TOKEN`)
- Komodo stack env vars must be explicitly mapped via `environment:` in compose.yaml - not auto-injected into the container
- `acme.json` must pre-exist as `{}` with mode `600` before first Traefik start
- `.homelab` (HTTP) was retired 2026-07-02 - `.home.example.com` (HTTPS) is the only URL scheme
