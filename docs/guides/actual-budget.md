# Personal Finance - Actual Budget

## What you'll end up with

Actual Budget running in CT 600 as a Komodo-managed Docker stack. Accessible at `https://budget.home.example.com:<admin-port>`. Your financial data stays fully local - no cloud sync, no accounts, no external dependencies.

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

!!! note "UID 1001 for Actual Budget"
    The Actual Budget image hardcodes UID 1001 internally. The script pre-creates the data directory owned by `1001:1001` so the container can write its database on first start.

---

## 3. Deploy via Komodo

Add CT 600 as a server in Komodo (`wss://<personal-apps-ip>:8120`), then deploy the `actual-budget` stack.

The stack exposes port `5006` and mounts `/data/actual-budget` as the data directory.

---

## 4. First-run setup

Open `http://<personal-apps-ip>:5006` (or via Traefik once the route is in place).

On first open, Actual Budget prompts you to create a local file or import a budget. No account or registration required.

---

## 5. Add the Traefik route

The route file is already in the repo at `stacks/personal-apps/traefik-route.yml`. Push it to the Traefik file provider directory in CT 100:

```bash
pct push 100 stacks/personal-apps/traefik-route.yml \
  /data/config/management/traefik/config/personal-apps.yml
```

Traefik picks it up automatically (no restart needed). Actual Budget is then accessible at `https://budget.home.example.com:<admin-port>`.

---

## Day-2 operations

### Updating Actual Budget

In Komodo UI: **Stacks → actual-budget → Deploy**. Pulls the latest image and restarts.

### Backing up data

Actual Budget stores everything in a single SQLite file at `/data/actual-budget/` inside CT 600 (bind-mounted from the host data disk). Back up that directory to keep a copy of your budget.

---

## Troubleshooting

**Container starts but data directory is not writable**

The image runs as UID 1001. Check that the host data directory is owned by the correct mapped UID:

```bash
ls -la $DATA_ROOT/config/personal-apps/actual-budget/
# Expected owner: 1001 (mapped through idmap to 101001 on the host)
```

If wrong: `chown -R 1001:1001 $DATA_ROOT/config/personal-apps/actual-budget/` then restart the stack.
