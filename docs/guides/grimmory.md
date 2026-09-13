# Digital Library - Grimmory

## What you'll end up with

Grimmory running in CT 600 as a Komodo-managed Docker stack with a MariaDB sidecar. A self-hosted ebook library with automatic metadata fetching from Google Books and Open Library, a built-in reader, and BookDrop auto-import. Accessible at `https://grimmory.<your-domain>`.

---

## Prerequisites

- Komodo running
- Traefik running
- Books directory exists on the data disk: `$DATA_ROOT/media-stack/media/books`

---

## 1. Create CT 600

Skip this step if CT 600 already exists.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/docker.sh)
```

| Setting | Value |
|---------|-------|
| CT ID | 600 |
| Hostname | personal-apps |
| Cores | 2 |
| RAM | 4096 MB |
| Disk | 8 GB |
| IP | `<your-ip>` |

---

## 2. Configure CT 600

These are host-level changes that need to be made before deploying Grimmory. Run everything on the **Proxmox host**.

### idmap - allow UID 1600 passthrough

Edit `/etc/pve/lxc/600.conf` and set the idmap entries:

```
lxc.idmap: u 0 100000 1000
lxc.idmap: u 1000 1000 700
lxc.idmap: u 1700 101700 63836
lxc.idmap: g 0 100000 1000
lxc.idmap: g 1000 1000 700
lxc.idmap: g 1700 101700 63836
```

Add to `/etc/subuid` and `/etc/subgid` (if not already present):

```
root:1000:700
```

### Books bind mount

```bash
pct set 600 -mp1 /your/data/media-stack/media/books,mp=/books
```

### RAM (if CT was created with less than 4096 MB)

```bash
pct set 600 --memory 4096
```

### Restart CT 600

```bash
pct stop 600 && pct start 600
```

---

## 3. Pre-create data directories

```bash
mkdir -p $DATA_ROOT/config/personal-apps/grimmory/{data,db,bookdrop}
chown -R 1600:1600 $DATA_ROOT/config/personal-apps/grimmory/
```

The `1600:1600` ownership passes through the idmap 1:1 - the container sees them as its own UID.

---

## 4. Add the stack .env

In the Komodo stack environment, add:

```
GRIMMORY_DB_PASSWORD=<strong-password>
GRIMMORY_DB_ROOT_PASSWORD=<strong-password>
```

---

## 5. Deploy via Komodo

In Komodo: **Stacks → grimmory → Deploy**.

!!! note "Slow first start"
    Spring Boot takes 3-5 minutes to initialize on first boot, longer if MariaDB needs to create the schema. The healthcheck will show unhealthy during that time - that is expected. Wait for the `grimmory` container to report healthy before opening the UI.

---

## 6. Add the Traefik route

Add a route to your Traefik file provider configuration:

```yaml
http:
  routers:
    grimmory:
      rule: "Host(`grimmory.<your-domain>`)"
      entryPoints: [websecure]
      service: grimmory
      middlewares: [admin-only]
      tls: {}
  services:
    grimmory:
      loadBalancer:
        servers:
          - url: "http://<personal-apps-ip>:6060"
```

Traefik picks it up automatically. Grimmory is then accessible at `https://grimmory.<your-domain>`.

---

## Day-2 operations

### Adding books

**Via BookDrop** - copy any ebook file into `$DATA_ROOT/config/personal-apps/grimmory/bookdrop/` on the host. Grimmory watches this folder and imports automatically.

**Via the UI** - use the upload button in the Grimmory web interface.

### Metadata lookup

Grimmory fetches metadata automatically on import. For a manual refresh or if metadata is missing:

1. Open the book in Grimmory
2. Click the edit panel and go to the **Match** tab
3. Enter the ISBN and search - results come from Google Books and Open Library
4. Select the correct result and apply

!!! tip "Anna's Archive epubs"
    Epubs from Anna's Archive often have malformed `dc:creator` fields (e.g. `Lastname, Firstname, Translator` as a single string) and non-standard identifiers. Grimmory may fail to auto-fetch metadata on import. Use the Match tab with the ISBN as a workaround - the corrected metadata is stored in MariaDB and does not require modifying the epub file.

### Updating Grimmory

In Komodo: **Stacks → grimmory → Deploy**. Pulls the latest image. Expect a few minutes for Spring Boot to reinitialize.

---

## Troubleshooting

**Stack deploys but grimmory container never becomes healthy**

Check that the DB came up first:

```bash
docker logs grimmory-db --tail 20
docker logs grimmory --tail 30
```

If the MariaDB healthcheck is failing the grimmory container will not start. The healthcheck uses `mariadb-admin ping` - if it's failing, verify the DB environment variables match between the two services.

**`DATABASE_USERNAME` / `DATABASE_PASSWORD` not recognized**

The correct env var names are `DATABASE_USERNAME` and `DATABASE_PASSWORD` (not `DB_USER` / `DB_PASSWORD`). The hostname in `DATABASE_URL` must match the MariaDB service name in compose (`grimmory-db`).

**Books directory empty / can't see books**

Verify the bind mount is present in `pct config 600` and that the host path exists. Also confirm `DISK_TYPE=LOCAL` is set - without it Grimmory won't scan local storage.
