# External Access - Cloudflare Tunnel

## What you'll end up with

Selected services reachable from the public internet via a Cloudflare Zero Trust tunnel. No inbound ports on your router, works behind CGNAT. The tunnel runs as a Docker container in CT 100 (`cloudflared` stack), connecting outbound to Cloudflare.

## Prerequisites

- Komodo running (CT 100, Traefik deployed)
- A Cloudflare account with your domain added
- Cloudflare Zero Trust enabled (free tier is sufficient)

---

## 1. Create a tunnel

In Cloudflare dashboard → **Zero Trust → Networks → Tunnels → Create a tunnel**:

1. Choose **Cloudflared** as the connector type
2. Name it (e.g. `homelab`)
3. Copy the tunnel token shown - you'll add it to the `cloudflared` stack `.env`

---

## 2. Configure the stack `.env`

The CT script placed a `.env` at `/data/config/management/komodo/periphery/stacks/cloudflared/.env`. Fill in the token:

```bash
pct exec 100 -- nano /data/config/management/komodo/periphery/stacks/cloudflared/.env
```

```env
CLOUDFLARE_TUNNEL_TOKEN=<your-tunnel-token>
```

---

## 3. Deploy via Komodo

In Komodo UI: **Stacks → Add Stack → cloudflared**, server `management`, files on host, deploy.

After a few seconds the tunnel should appear as **Healthy** in Cloudflare Zero Trust → Tunnels.

---

## 4. Add a public hostname

In Cloudflare Zero Trust → **Tunnels → your tunnel → Public Hostname → Add**:

| Field | Value |
|-------|-------|
| Subdomain | `service` (e.g. `panel`) |
| Domain | `example.com` |
| Type | `HTTP` |
| URL | `<mgmt-ip>:80` (Traefik, plain HTTP internally) |

This creates a public DNS record and routes `https://service.example.com` → Cloudflare → tunnel → Traefik → service.

!!! warning "Scope public routes carefully"
    Only expose the minimum. Each public hostname should route to one specific service via Traefik. Don't create a wildcard or route to the Traefik dashboard.

---

## 5. Add the Traefik route

For each publicly exposed service, add a Traefik route file on CT 100. The public hostname hits Traefik on port 80 (plain HTTP from the tunnel - TLS is terminated at Cloudflare). Route it to the service backend:

```yaml
http:
  routers:
    mypanel-public:
      rule: "Host(`panel.example.com`)"
      entryPoints:
        - web
      service: mypanel

  services:
    mypanel:
      loadBalancer:
        servers:
          - url: "http://<panel-ip>:80"
```

Place this file in `/data/config/management/traefik/config/` on CT 100. Traefik hot-reloads it.

!!! warning "Don't skip access controls on public routes"
    Internal routes are safe behind Pi-hole + Tailscale. Public routes are reachable by anyone. Use Cloudflare Access policies (Zero Trust → Access → Applications) to gate anything sensitive, or ensure the service itself requires authentication.

---

## Stopping the tunnel

If you want to stop public access without losing the config:

1. **Stop the stack** in Komodo (or `docker stop cloudflared` in CT 100)
2. **Disable the Traefik route** - rename the route file to add `.disabled` (don't just stop the container; the route file stays active in Traefik and any device with the right `Host` header can still reach it)

```bash
pct exec 100 -- mv /data/config/management/traefik/config/cloudflared-public.yml \
                   /data/config/management/traefik/config/cloudflared-public.yml.disabled
```

To reactivate: rename the file back and start the stack in Komodo.

---

## Day-2 operations

### Updating cloudflared

`cloudflared` is a Docker container managed by Komodo. In Komodo UI: **Stacks → cloudflared → Deploy**. Pulls the latest image and restarts.

Cloudflare's connector auto-updates itself by default, but a manual deploy will also pick up any image changes.

---

## Limitations

- Cloudflare Tunnel only supports HTTP/HTTPS, not raw TCP - you can't tunnel game server ports (UDP) or SFTP through it
- Latency is higher than Tailscale due to Cloudflare's routing; not suitable for latency-sensitive services
- For Minecraft: use Tailscale sharing instead (see [Tailscale guide](tailscale.md))

---

## Troubleshooting

**Tunnel shows as unhealthy in Cloudflare**

1. Check the container is running: `pct exec 100 -- docker ps | grep cloudflared`
2. Check logs: `pct exec 100 -- docker logs cloudflared --tail 50`
3. Confirm the token in `.env` matches what Cloudflare shows for the tunnel

**Public hostname returning 502**

Traefik is receiving the request but can't reach the backend. Check:
- The route file URL is correct and the service is running
- The route is using `entryPoints: [web]` (port 80), not `websecure` - the tunnel sends plain HTTP to Traefik
