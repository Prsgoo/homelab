# Recipe Manager - Mealie

## What you'll end up with

Mealie running in CT 600 as a Komodo-managed Docker stack. A self-hosted recipe manager with meal planning and shopping list generation, accessible at `https://mealie.home.example.com:<admin-port>`. No database container needed - Mealie uses SQLite by default.

---

## Prerequisites

- Komodo running
- Traefik running

---

## 1. Create CT 600

CT 600 hosts all personal apps (Actual Budget, Mealie). If it's already running from another personal app guide, skip to step 3.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/docker.sh)
```

| Setting | Value |
|---------|-------|
| CT ID | 600 |
| Hostname | personal-apps |
| Cores | 2 |
| RAM | 1024 MB |
| Disk | 8 GB |
| IP | <personal-apps-ip>/24 |

---

## 2. Run the CT script

```bash
cd /opt/proxmox-admin
bash scripts/ct600-personal-apps.sh
```

This sets directory ownership, applies bind mounts, and installs Periphery. The script is idempotent - safe to run again if CT 600 already exists.

!!! note "UID 911 for Mealie"
    The Mealie image runs internally as UID 911. The script pre-creates the data directory owned by the correctly mapped host UID so the container can write on first start.

---

## 3. Deploy via Komodo

Add CT 600 as a server in Komodo (`wss://<personal-apps-ip>:8120`), then deploy the `mealie` stack.

The stack exposes port `9000` and mounts `/data/mealie` as the data directory.

---

## 4. First-run setup

Open `http://<personal-apps-ip>:9000`.

Mealie prompts you to create an admin account on first run. The default credentials shown in the UI are `changeme@example.com` / `MyPassword` - log in with those, then immediately update the email and password.

`ALLOW_SIGNUP=false` is set in the compose, so no other users can register after initial setup.

---

## 5. Add the Traefik route

The route file covers both personal apps (Actual Budget and Mealie) in a single file. If you've already pushed it for Actual Budget, skip this step.

```bash
pct push 100 stacks/personal-apps/traefik-route.yml \
  /data/config/management/traefik/config/personal-apps.yml
```

Traefik picks it up automatically. Mealie is then accessible at `https://mealie.home.example.com:<admin-port>`.

---

## Day-2 operations

### Updating Mealie

In Komodo UI: **Stacks → mealie → Deploy**. Pulls the latest image and restarts.

### Backing up data

Mealie stores everything (SQLite database, recipe images) in `/data/mealie/` inside CT 600 (bind-mounted from the host data disk). Back up that directory to preserve your recipes.

---

## Troubleshooting

**Container starts but data directory is not writable**

The image runs as UID 911. Check that the host data directory is owned by the correct mapped UID:

```bash
ls -la $DATA_ROOT/config/personal-apps/mealie/
# Expected owner: 100911 (UID 911 mapped through idmap)
```

If wrong: `chown -R 100911:100911 $DATA_ROOT/config/personal-apps/mealie/` then restart the stack.

---

**Can't log in with default credentials**

Mealie only shows the default credentials (`changeme@example.com` / `MyPassword`) on a fresh database. If you've already set up an account and forgotten the password, reset it via the CLI:

```bash
pct exec 600 -- docker exec mealie python /app/mealie/scripts/change_password.py
```

**Recipe images not loading after restore**

Images are stored alongside the database in `/data/mealie/`. If you restored only the database file and not the full directory, images will be missing. Always back up the full directory.
