---
title: FileBrowser
updated: 2026-08-05
---

# FileBrowser

LXC: [management lxc](../../lxcs/management-lxc.md) (CT 100) - web-based file manager for editing Traefik routes, Glance config, and stack compose files without SSH.

## Instance

| Setting | Value |
|---------|-------|
| Port | 8082 |
| Root | `/data/` (full `$DATA_ROOT/` pool) |
| Database | `/data/config/management/filebrowser/filebrowser.db` |
| URL | `https://files.home.example.com:<admin-port>` |
| Managed as | Komodo stack `filebrowser` |

## File Permissions Note

FileBrowser creates new files as `640`. `acme.json` must be `600` - chmod it after creating.
