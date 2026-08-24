# Reverse Proxy - Traefik

## What you'll end up with

Traefik v3 running as a Komodo-managed stack on CT 100. A wildcard Let's Encrypt cert for `*.home.example.com` obtained via Cloudflare DNS-01 challenge - no ports open to the internet. Every internal service reachable at `https://<name>.home.example.com`. Two entrypoints: one for user-facing services (`:443`) and one for admin-only tools (port is yours to choose - see Entrypoints section).

---

## Prerequisites

- Komodo running (CT 100 up, Komodo Core deployed)
- Pi-hole + Unbound running with the `*.home.example.com` redirect zone in place
- A domain managed in Cloudflare DNS
- A Cloudflare API token with `Zone:DNS:Edit` + `Zone:Zone:Read` permissions on your zone

---

## 1. Create the Cloudflare API token

In Cloudflare dashboard → **My Profile → API Tokens → Create Token**:

- Use the "Edit zone DNS" template
- Zone resources: **Include → Specific zone → your domain**
- Save the token - you'll add it to the Traefik stack `.env`

---

## 2. Pre-create `acme.json`

Traefik stores Let's Encrypt certificates in `acme.json`. It must exist as an empty JSON file with mode `600` **before first start** - Traefik will refuse to start if it's missing or has wrong permissions.

Inside CT 100:

```bash
pct exec 100 -- bash -c '
  mkdir -p /data/config/management/traefik/acme
  echo "{}" > /data/config/management/traefik/acme/acme.json
  chmod 600 /data/config/management/traefik/acme/acme.json
'
```

!!! warning "Do this before deploying"
    If Traefik starts without `acme.json` existing, it may create it with wrong permissions or fail entirely. The cert request will not succeed until this is correct.

---

## 3. Set up the stack `.env`

The CT script placed a `.env` file at `/data/config/management/komodo/periphery/stacks/traefik/.env`. Fill in the Cloudflare token:

```bash
pct exec 100 -- nano /data/config/management/komodo/periphery/stacks/traefik/.env
```

```env
CLOUDFLARE_DNS_API_TOKEN=<your-token>
```

!!! note "Token variable name"
    Traefik's Cloudflare provider expects `CLOUDFLARE_DNS_API_TOKEN` - not the older `CF_DNS_API_TOKEN`. Using the wrong name causes silent cert request failures.

---

## 4. Update static config

The Traefik static config at `stacks/management/traefik/traefik.yml` needs your domain and email. The repo has placeholders - update them before deploying:

```yaml
certificatesResolvers:
  cloudflare:
    acme:
      email: admin@example.com        # your email for Let's Encrypt expiry notices
      storage: /etc/traefik/acme/acme.json
      dnsChallenge:
        provider: cloudflare
        resolvers:
          - "1.1.1.1:53"
          - "8.8.8.8:53"
```

Also update the domain in `stacks/management/traefik/traefik-route.yml` - this is the router that requests the wildcard cert:

```yaml
    traefik-tls:
      rule: "Host(`traefik.home.example.com`)"
      tls:
        certResolver: cloudflare
        domains:
          - main: "home.example.com"
            sans:
              - "*.home.example.com"
```

Push the updated static config to CT 100:

```bash
pct exec 100 -- mkdir -p /data/config/management/traefik/config
pct push 100 stacks/management/traefik/traefik.yml /data/config/management/traefik/traefik.yml
pct push 100 stacks/management/traefik/traefik-route.yml /data/config/management/traefik/config/traefik-route.yml
```

---

## 5. Deploy via Komodo

In Komodo UI:

1. **Stacks → Add Stack**
2. Server: `management`
3. Stack name: `traefik`
4. Directory: `stacks/traefik` (relative to Periphery root)
5. Enable **Files on Host**
6. Click **Deploy**

Traefik starts and immediately begins the Cloudflare DNS-01 challenge for the wildcard cert. The challenge takes 30–90 seconds. You can watch it in CT 100:

```bash
pct exec 100 -- docker logs traefik -f
```

Look for `"Certificate obtained successfully"`. After that, `https://traefik.home.example.com:<admin-port>/dashboard/` should load.

!!! note "Dashboard URL"
    The trailing slash on `/dashboard/` is required. `/dashboard` without it returns 404.

---

## 6. Entrypoints

Traefik exposes three entrypoints:

| Name | Port | Purpose |
|------|------|---------|
| `web` | `:80` | HTTP (unused - no services on plain HTTP) |
| `websecure` | `:443` | User-facing services |
| `admin` | `<your-admin-port>` | Admin tools - Tailscale-only access |

Admin tools use the `admin-only` middleware, which restricts access to Tailscale IP ranges. Services on `:443` are accessible from the LAN and Tailscale.

!!! note "Choosing your admin port"
    `<admin-port>` throughout this documentation is a placeholder. Pick any unused port on your host (e.g. `8443`, `9443`, or any high port) and set it under `entryPoints.admin.address` in `traefik.yml`. All service guides use `<admin-port>` in URLs - substitute your chosen value.

---

## 7. Adding a new service route

Create a YAML file in `/data/config/management/traefik/config/` on CT 100. Traefik hot-reloads on file change - no restart needed.

**User-facing service (`:443`):**

```yaml
http:
  routers:
    myservice:
      rule: "Host(`myservice.home.example.com`)"
      entryPoints:
        - websecure
      service: myservice
      tls: {}

  services:
    myservice:
      loadBalancer:
        servers:
          - url: "http://<server-ip>:PORT"
```

**Admin tool (`<admin-port>`, Tailscale-only):**

```yaml
http:
  routers:
    myservice:
      rule: "Host(`myservice.home.example.com`)"
      entryPoints:
        - admin
      middlewares:
        - admin-only@file
      service: myservice
      tls: {}
  ...
```

The `tls: {}` block (no `certResolver`) reuses the already-cached wildcard cert.

---

## Day-2 operations

### Updating Traefik

In Komodo UI: **Stacks → traefik → Deploy**. Pulls the latest image and restarts.

### Checking cert expiry

```bash
pct exec 100 -- cat /data/config/management/traefik/acme/acme.json | python3 -c "
import json,sys
data=json.load(sys.stdin)
for r in data.values():
    for cert in r.get('Certificates',[]):
        print(cert['domain']['main'], cert['domain'].get('sans',[]))
"
```

Traefik auto-renews certs 30 days before expiry.

### Viewing access logs

```bash
pct exec 100 -- docker logs traefik --tail 100
```

---

## Troubleshooting

**Cert request failing / `acme.json` errors**

1. Confirm the token variable is `CLOUDFLARE_DNS_API_TOKEN` (not `CF_DNS_API_TOKEN`)
2. Confirm the token has `Zone:DNS:Edit` on the correct zone
3. Check `acme.json` permissions: `pct exec 100 -- ls -la /data/config/management/traefik/acme/acme.json` - must be `600`

**`ipAllowList` not working (admin tools reachable from LAN)**

Check that `userland-proxy: false` is in `/etc/docker/daemon.json` on CT 100 and Docker was restarted after setting it. Without it, all source IPs appear as the bridge gateway and allowlists match nothing.

**Service route not loading**

Route files hot-reload. Check Traefik dashboard → **HTTP → Routers** for the route and any error status. Common issues: YAML indentation error, wrong entrypoint name, service URL unreachable.
