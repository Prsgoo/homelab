---
title: FileBrowser
updated: 2026-10-19
---

# FileBrowser

LXC: [management lxc](../../lxcs/management-lxc.md) (CT 100) - web-based file manager for editing Traefik routes, Glance config, and stack compose files without SSH. Runs [FileBrowser Quantum](https://github.com/gtsteffaniak/filebrowser) (`gtstef/filebrowser:stable`), the actively maintained fork.

## Instance

| Setting | Value |
|---------|-------|
| Port | 8082 |
| Root | `/data/` (full `$DATA_ROOT/` pool) |
| Database | `/data/config/management/filebrowser/database/filebrowser.sqlite` |
| Config | `/data/config/management/filebrowser/config/config.yaml` |
| URL | `https://files.home.<your-domain>:<admin-port>` |
| Managed as | Komodo stack `filebrowser` |

## File Permissions Note

FileBrowser creates new files as `640`. `acme.json` must be `600` - chmod it after creating.
