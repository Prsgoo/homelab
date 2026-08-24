---
title: Komodo
updated: 2026-08-05
---

# Komodo

Container and stack manager. Komodo Core runs in CT 100 (management). Every other Docker LXC that needs to be managed runs the Komodo Periphery binary agent.

See [management lxc](../lxcs/management-lxc.md) for Core setup (Compose file, MongoDB, API access).

## Periphery - Standard Setup

Every managed Docker LXC runs the Periphery binary. Always use the install script:

```bash
curl -fsSL https://raw.githubusercontent.com/moghtech/komodo/main/scripts/setup-periphery.py | python3
```

After install, add env vars to the service file (`/etc/systemd/system/periphery.service`):

```ini
[Service]
ExecStart=/usr/local/bin/periphery
Environment=PERIPHERY_CONFIG_PATH=/etc/komodo/periphery.config.toml
Environment=PERIPHERY_ROOT_DIRECTORY=/data/komodo   # Docker LXCs only - omit for native-install LXCs
```

Config (`/etc/komodo/periphery.config.toml`):

```toml
[periphery]
port = 8120

[core]
addresses = ["ws://<mgmt-ip>:9120"]
```

Standard file locations:
- Binary: `/usr/local/bin/periphery`
- Service: `periphery.service`

Komodo server address (set in UI or API) must use `wss://` - Periphery auto-generates a self-signed cert.

## Stack File Conventions

| LXC type | Stack root | Stack path pattern |
|----------|------------|--------------------|
| CT 100 (Docker Periphery) | `/data/config/management/komodo/periphery/` | `stacks/<name>/compose.yaml` |
| Other Docker LXCs (binary Periphery) | `/data/komodo/` | `stacks/<name>/compose.yaml` |

`PERIPHERY_ROOT_DIRECTORY` is required on Docker LXCs - the TOML `root_directory` key is silently ignored.

## Stack Creation Workflow

New stacks created via API always start as "UI defined" (Komodo stores compose in DB). Switch to "files on host" after first deploy:

1. `CreateStack` with `file_contents` → Komodo stores compose
2. `DeployStack` → Komodo writes compose to disk at the stack path
3. `UpdateStack` with `files_on_host: true, file_contents: ""` → future deploys read from disk

Never skip step 3 - UI defined stacks overwrite the on-disk compose on every deploy, making manual edits impossible.

## Gotchas

- Servers created via API default to `enabled: false` - must enable after creation
- **Key rotation / version mismatch:** Komodo shows `NotOk` with "public key invalid". Root cause is almost always a Core/Periphery version mismatch. Fix: reinstall Periphery using `--version vX.Y.Z` matching Core's version.
- **Periphery v2.2.0 vs v2.1.2:** v2.2.0 changed to outbound-only mode (Periphery → Core, no listening). v2.1.2 uses dual-connection (Periphery → Core outbound + Core → Periphery inbound on `wss://`). All servers in this homelab use v2.1.2 to match Core.
- **Periphery v2.x install with version pin:** `curl -fsSL .../setup-periphery.py | python3 - --version v2.1.2 --root_directory /data/komodo`
- Game-panel (CT 400) omits `PERIPHERY_ROOT_DIRECTORY` - Pterodactyl runs natively, no Docker stacks

## Key Takeaways

- `PERIPHERY_ROOT_DIRECTORY` must be a systemd env var - TOML key is ignored
- Komodo server address always uses `wss://` (Periphery auto-generates SSL)
- Stack files on disk are the source of truth after switching to `files_on_host: true`
