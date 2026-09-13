---
title: Cloudflare Tunnel
updated: 2026-09-13
---

# Cloudflare Tunnel

Exposes homelab services to the public internet without opening inbound ports. `cloudflared` connects outbound to Cloudflare - works behind CGNAT. Managed as a Komodo stack on CT 100.

## Architecture

```
Internet → Cloudflare DNS (CNAME) → Cloudflare Tunnel → cloudflared (CT 100) → Traefik (CT 100) → service
```

## Setup

1. Create the tunnel in the [Cloudflare Zero Trust dashboard](https://one.dash.cloudflare.com/) and copy the tunnel token.
2. Add `CLOUDFLARE_TUNNEL_TOKEN` to the stack `.env`.
3. Add the public hostnames in Cloudflare Zero Trust → Tunnels → Public Hostnames.
4. Deploy the `cloudflared` stack in Komodo.
5. Add a Traefik route file pointing the public hostname to the internal service. Example for a service on port 8081:

```yaml
http:
  routers:
    myservice-public:
      rule: "Host(`myservice.<your-domain>`)"
      entryPoints: [web, websecure]
      service: myservice
      middlewares: [https-redirect]
  services:
    myservice:
      loadBalancer:
        servers:
          - url: "http://<server-ip>:8081"
```

Ensure each public route has an `ipAllowList` middleware scoped to exactly that service before exposing it.

## Key Takeaways

- Cloudflare Tunnel only supports HTTP/HTTPS, not raw TCP - rules out Minecraft and similar raw TCP services
- **Stopping the tunnel container is not enough** - the Traefik route file stays active and unguarded unless explicitly disabled or removed too
- Public routes need explicit `ipAllowList` scoping - without it they're reachable by anyone sending the right `Host` header
- If adding a new public service: scope the route to exactly that one hostname, don't piggyback on existing routes
- `*.<your-domain>` (internal Tailscale-only) is unrelated to this - see [internal https](internal-https.md)
