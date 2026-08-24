---
title: Komodo Core
updated: 2026-08-05
---

# Komodo Core

LXC: [management lxc](../../lxcs/management-lxc.md) (CT 100) - container and stack manager for the entire homelab.
See [komodo](../../infrastructure/komodo.md) for the architecture, Periphery setup pattern, and stack conventions.

## Instance

| Setting | Value |
|---------|-------|
| Compose | `/opt/komodo/compose.yaml` |
| Env file | `/opt/komodo/compose.env` |
| Data | `/data/config/management/komodo/` |
| UI | `http://<mgmt-ip>:9120` |
| API | `https://komodo.home.example.com:<admin-port>` |

## Components

| Container | Role |
|-----------|------|
| Komodo Core | Manager UI + API |
| MongoDB | State store |
| Komodo Periphery | Local agent (Docker container, not binary) |

CT 100's Periphery runs as a Docker container inside the Komodo compose - it is the "Local" server in Komodo. All other LXCs run the binary Periphery agent.

## Start / Restart

```bash
cd /opt/komodo && docker compose --env-file compose.env -f compose.yaml up -d
```

## Stack File Location (CT 100)

Stacks managed by the local (CT 100) Periphery live at:
```
/data/config/management/komodo/periphery/stacks/<name>/compose.yaml
```

All other LXCs use binary Periphery with root at `/data/komodo/stacks/<name>/compose.yaml`.

## Stack Creation Workflow

New stacks created via API start as "UI defined" (compose stored in DB). Switch to files on host after first deploy:

1. `CreateStack` with `file_contents` → Komodo stores compose in DB
2. `DeployStack` → Komodo writes compose to disk at the stack path
3. `UpdateStack` with `files_on_host: true, file_contents: ""` → future deploys read from disk

Never skip step 3 - UI defined stacks overwrite the on-disk compose on every deploy.

## Key Takeaways

- Secrets (`MONGO_PASSWORD`, `KOMODO_PASSKEY`, `KOMODO_JWT_SECRET`) must be in a password manager - not stored in the repo
- CT 100 is the "Local" server; its Periphery is a Docker container, not a binary install
- API token credentials are in the project `.env` file (not committed)
