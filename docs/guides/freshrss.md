# RSS Reader - FreshRSS

## What you'll end up with

FreshRSS running in CT 600 as a Komodo-managed Docker stack. A self-hosted RSS aggregator accessible at `https://freshrss.<your-domain>:<admin-port>`. No database container needed - FreshRSS uses SQLite by default. Feeds auto-refresh every 30 minutes via the built-in cron.

---

## Prerequisites

- CT 600 (personal-apps) running
- Komodo running with the personal-apps server registered
- Traefik running

---

## 1. Create the data directory

On the **Proxmox host root shell**:

```bash
mkdir -p $DATA_ROOT/config/personal-apps/freshrss
chown -R 100033:100033 $DATA_ROOT/config/personal-apps/freshrss
```

`100033` is www-data (UID 33 inside the LXC) mapped through the idmap offset. The FreshRSS entrypoint runs as root but Apache serves as www-data - the directory must be pre-owned or the install wizard will fail with permission errors.

---

## 2. Deploy via Komodo

Create a new stack on the `personal-apps` server with root directory `/data/komodo/stacks/freshrss`. Compose file at `stacks/personal-apps/freshrss/compose.yaml`:

```yaml
services:
  freshrss:
    image: freshrss/freshrss:latest
    restart: unless-stopped
    ports:
      - "8080:80"
    volumes:
      - /data/freshrss:/var/www/FreshRSS/data
    environment:
      - TZ=Europe/Madrid
      - CRON_MIN=*/30
```

Deploy the stack. The image pull takes ~30 seconds.

---

## 3. First-run setup

Open `http://<personal-apps-ip>:8080` (or `https://freshrss.<your-domain>:<admin-port>` once the Traefik route is in place).

The install wizard walks through:

1. **Check** - confirms PHP extensions and directory permissions are okay
2. **Database** - select SQLite, leave the default path
3. **General settings** - set your admin username, password, and language
4. **Finish** - login and start adding feeds

To import feeds in bulk, go to **Subscriptions → Import/Export → Import OPML** and upload an OPML file.

---

## 4. Add the Traefik route

The route file covers all personal apps in a single file. If already pushed for another personal app, just append the FreshRSS entries or push the updated file:

```bash
pct push 100 stacks/personal-apps/traefik-route.yml \
  /data/config/management/traefik/config/personal-apps.yml
```

Traefik picks it up immediately. FreshRSS is then accessible at `https://freshrss.<your-domain>:<admin-port>`.

---

## Day-2 operations

### Updating FreshRSS

In Komodo UI: **Stacks → freshrss → Deploy**. Pulls the latest image and restarts. Config and feeds are preserved via the bind mount.

### Backing up data

Everything (SQLite database, feed cache, user config) lives in `$DATA_ROOT/config/personal-apps/freshrss/`. Back up that directory.

### Adjusting feed refresh interval

Edit `CRON_MIN` in the compose and redeploy. Examples:
- `*/15` - every 15 minutes
- `0 * * * *` - hourly
- `0 */6 * * *` - every 6 hours

### Mobile clients

FreshRSS supports the Google Reader API and Fever API. Enable them under **Settings → Authentication** (set API password). Compatible clients: NetNewsWire, FeedMe, Reeder, ReadYou.

---

## Troubleshooting

**Install wizard shows permission errors on `/var/www/FreshRSS/data`**

The data directory isn't owned by www-data. Fix from the Proxmox host root shell:

```bash
chown -R 100033:100033 $DATA_ROOT/config/personal-apps/freshrss
```

Then restart the container and refresh the wizard page.

**Feeds not updating automatically**

Check that `CRON_MIN` is set in the compose. FreshRSS only enables the cron daemon when this variable is present. Verify it's running inside the container:

```bash
docker exec freshrss-freshrss-1 ps aux | grep cron
```
