---
title: Cloudflare Tunnel
updated: 2026-08-05
---

# Cloudflare Tunnel

**Stopped (not removed) 2026-06-19.** Everyone who needs access to the homelab installs Tailscale, so there's no current use case for public exposure. Glance and Seerr (the two services that were tunneled) are now Tailscale-only, gated by per-device `tag:streaming`/`tag:admin` ACL grants and Traefik's `ipAllowList` middleware.

Decision: keep the config intact rather than delete it, since a future portfolio site is a planned reason to bring public exposure back. Everything below can be reactivated without rebuilding it from scratch.

## What was actually done

- The `cloudflared` Komodo stack was **stopped** (`docker stop`, via Komodo's `StopStack`) - not destroyed. Container still exists, `restart: unless-stopped` means it stays down across host reboots until manually started again.
- The live Traefik route file `/data/config/management/traefik/config/cloudflared-public.yml` was **renamed to `cloudflared-public.yml.disabled`** rather than deleted. This matters: stopping the `cloudflared` container only closes the *public internet* path - it does nothing to the route definitions Traefik already has loaded. Since `glance-public`/`seerr-public` had no `ipAllowList` at all, they remained reachable by any Tailscale-tagged device sending the public `Host` header directly to port 80, completely bypassing Glance's move to admin-only. Renaming (not deleting) closes that gap while preserving the content.
- Repo files (`stacks/management/cloudflared/compose.yaml`, `traefik-routes.yml`) were kept as-is - they're just source-of-truth references, not auto-applied, so there's no equivalent risk in leaving them in the repo.

## To bring it back later

1. Rename `cloudflared-public.yml.disabled` back to `cloudflared-public.yml` on the server (or recreate it from `stacks/management/cloudflared/traefik-routes.yml` in this repo).
2. Start the `cloudflared` stack in Komodo.
3. Re-add the public hostnames in Cloudflare Zero Trust dashboard if they were removed there too.
4. **Decide on `ipAllowList` for the public routes** - if reactivating for a portfolio site, scope the route to exactly that one new service, not Glance/Seerr, given the gap described above.

## Previous/parked architecture (for reference)

```
Internet → Cloudflare DNS (CNAME) → Cloudflare Tunnel → cloudflared (CT 100) → Traefik (CT 100) → service
```

`cloudflared` connects outbound to Cloudflare - no inbound ports, works behind CGNAT. Previously tunneled:

| Public URL | Internal target |
|-----------|----------------|
| `glance.example.com` | `http://<mgmt-ip>:8081` |
| `seerr.example.com` | `http://<media-arr-ip>:5055` |

## Key Takeaways

- Cloudflare Tunnel only supports HTTP/HTTPS, not raw TCP - would have ruled out Minecraft regardless
- **Stopping the tunnel container is not enough on its own** - the Traefik route file it depends on stays active and unguarded unless explicitly disabled too
- If reactivated for a portfolio site: scope the route to exactly that one public hostname, nothing more
- `*.home.example.com` (internal-only, no public DNS) is unrelated to this and unaffected - see [internal https](internal-https.md)
- Current access model for everything previously public here: [tailscale](tailscale.md) and [management lxc](../lxcs/management-lxc.md)
