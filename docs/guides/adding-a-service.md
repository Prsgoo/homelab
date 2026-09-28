---
title: Adding a New Service or CT
updated: 2026-09-28
---

# Adding a New Service or CT

Use this guide every time a new service is added to an existing CT, or a new CT is created. Following this checklist keeps the UID scheme, scripts, and docs in sync and prevents the normalization drift that happens when services are added ad-hoc.

---

## Quick Checklist

### New service in an existing CT

- [ ] Assign UID from the CT's block - add row to `user-group-scheme.md`
- [ ] If image ignores PUID/PGID - add entry to `service-uid-exceptions.md`
- [ ] Add `add_user` to the CT setup script (always, even for exceptions)
- [ ] Add config dir `mkdir` + `chown` + `chmod` to the script (if bind mount exists)
- [ ] Add `deploy_stack` to the script
- [ ] Create `stacks/<ct-name>/<service>/compose.yaml` in the repo
- [ ] Add row to permissions table in `user-group-scheme.md`
- [ ] Add `useradd` to the host users list in `lxc-idmap.md`
- [ ] Update the LXC's wiki page (`docs/wiki/lxcs/<ct-name>.md`)
- [ ] Mirror all changes to `homelab/` (strip sensitive info)

### New CT

- [ ] Everything in the service checklist above, for each service
- [ ] Assign UID block (10 UIDs per CT, mirrors CT number range)
- [ ] Create CT via community-scripts Docker LXC helper
- [ ] Add idmap block to `/etc/pve/lxc/<vmid>.conf` before first start
- [ ] Create `scripts/ct<id>-<name>.sh`
- [ ] Create `docs/wiki/lxcs/<ct-name>.md`
- [ ] Create `docs/wiki/services/<ct-name>/_index.md`
- [ ] Update `docs/wiki/_master-index.md`
- [ ] Mirror everything to `homelab/`

---

## Step-by-Step: Adding a Service

### 1. Assign a UID

Open `docs/wiki/standards/user-group-scheme.md`. Find the CT's UID block in the Per-Service Users table. Pick the next available UID.

UID block convention:
- CT 300-309 services → UIDs 1300-1309
- CT 301 services → UIDs 1310-1319
- CT 302 services → UIDs 1320-1329
- CT 303 services → UIDs 1330-1339
- CT 600 services → UIDs 1600-1699

Add a row:
```
| <UID> | `<name>` | <Service> | <GID> (`<group>`) | - | CT <id> (<ct-name>) |
```

If the image doesn't use PUID/PGID, append "- UID unused, see [exceptions](service-uid-exceptions.md)" to the note.

### 2. Check for PUID/PGID support

Does the image support PUID/PGID env vars (most LinuxServer.io images do)?

**Yes** - standard path: set `PUID=<uid>` and `PGID=<gid>` in compose, own the config dir with `<uid>:<gid>`.

**No** - find out what UID the image actually runs as:
- Check the image's Dockerfile or docs
- Common cases: hardcoded internal user, `node` (UID 1000), `www-data` (UID 33), service-specific UID

Add an entry to `docs/wiki/standards/service-uid-exceptions.md` documenting:
- Why PUID/PGID doesn't work
- What UID the container actually runs as
- What that UID maps to on the host (via the CT's idmap)
- The correct `chown` command for the host-side config dir

### 3. The normalization rule - critical

**The system user at the reserved UID must always be created**, even if the service doesn't use it.

This means: even for exception services (dispatcharr, flaresolverr, seerr, etc.), `add_user <reserved-uid> <gid> <name>` must be in the CT script and the corresponding `useradd` must be in `lxc-idmap.md`.

The reserved UID user and the actual runtime UID are separate things. The reserved UID user exists purely for scheme consistency. The runtime UID (which may be different) is what owns the config dir.

### 4. Update the CT setup script

Open `scripts/ct<id>-<name>.sh`. Add to the Users & groups section:

```bash
add_user <uid> <gid> <name>
```

If the service has a config bind mount, add to the Data directory ownership section:

```bash
# Standard path (PUID/PGID works)
mkdir -p $DATA_ROOT/config/<ct-name>/<service>
chown <uid>:<gid> $DATA_ROOT/config/<ct-name>/<service> && chmod 750 $DATA_ROOT/config/<ct-name>/<service>

# Exception path (different runtime UID)
mkdir -p $DATA_ROOT/config/<ct-name>/<service>
chown <host-runtime-uid>:<host-runtime-gid> $DATA_ROOT/config/<ct-name>/<service> && chmod 750 $DATA_ROOT/config/<ct-name>/<service>
```

For the exception path: calculate the host-side UID from the CT's idmap. UIDs 1000-1499 pass through 1:1. UIDs 0-999 get +100000 (so container UID 33 → host UID 100033, container UID 911 → host UID 100911).

Add to the Stack files section:

```bash
deploy_stack "$STACKS_DIR/<service>" "<ct-name>/<service>"
```

### 5. Create the stack file

Create `stacks/<ct-name>/<service>/compose.yaml` in the repo. The `deploy_stack` function copies this to the Komodo stacks dir on the host when the CT script runs.

### 6. Update the permissions table

Add a row to the `$DATA_ROOT Directory Permissions Reference` table in `user-group-scheme.md`:

```
| `$DATA_ROOT/config/<ct-name>/<service>/` | `<host-uid>:<host-gid>` | 750 | <note> |
```

Skip this row only if the service has no config bind mount (e.g. named volume only, or stateless).

### 7. Update lxc-idmap.md

Add to the correct section under Host-side users and groups:

```bash
useradd -u <uid> -g <gid> -s /bin/false -d /nonexistent <name>
```

This is the reserved UID user - always added, even for exceptions.

### 8. Update the LXC wiki page

Open `docs/wiki/lxcs/<ct-name>.md`. Add a row to the UID/GID Scheme table:

```
| <uid> | <Service> | <note - mention if reserved/exception> |
```

### 9. Mirror to public repo

Apply the same changes to `homelab/`. Replace sensitive values with placeholders per the table in `CLAUDE.md`. The scripts contain no sensitive info (no real IPs, tokens, or domains) and can be copied verbatim.

---

## Step-by-Step: Creating a New CT

### 1. Plan the CT

- Pick the next available VMID in the correct range (300-399 for media, 600-699 for personal, etc.)
- Assign a 10-UID block mirroring the VMID range
- Decide which shared group(s) it needs (`media`, `personal-apps`, etc.)
- Plan bind mounts and which host paths they come from

### 2. Create the CT

Use the Proxmox community-scripts Docker LXC helper (always Debian 13):

```bash
bash -c "$(wget -qLO - https://github.com/community-scripts/ProxmoxVE/raw/main/ct/docker.sh)"
```

Set hostname, storage, and resources. Do not start yet.

### 3. Add the idmap block

In the Proxmox root shell, before starting the CT:

```bash
cat >> /etc/pve/lxc/<vmid>.conf << 'EOF'
lxc.idmap: u 0 100000 1000
lxc.idmap: u 1000 1000 500
lxc.idmap: u 1500 101500 64036
lxc.idmap: g 0 100000 1000
lxc.idmap: g 1000 1000 500
lxc.idmap: g 1500 101500 64036
EOF
```

Adjust the range if the CT's service UIDs exceed 1499. CT 600 uses 1000-1699 so its range is 700 wide.

Also add to `/etc/subuid` and `/etc/subgid` if using a non-standard range:

```bash
echo "root:1000:500" >> /etc/subuid
echo "root:1000:500" >> /etc/subgid
```

### 4. Create the CT setup script

Copy an existing script as a template (e.g. `cp scripts/ct300-media-arr.sh scripts/ct<id>-<name>.sh`). Update:
- Header comment
- VMID
- STACKS_DIR
- Users & groups section (all services)
- Data directory ownership section (all config dirs)
- LXC conf patches (mount points + idmap)
- Stack files section (all stacks)

### 5. Create wiki docs

**LXC page:** `docs/wiki/lxcs/<ct-name>.md`
- Specs table (VMID, hostname, template, resources, IP)
- Bind Mounts table
- idmap block
- UID/GID Scheme table (all services, including exceptions)
- Komodo section
- Services section (link to service index)

**Service index:** `docs/wiki/services/<ct-name>/_index.md`
- One section per service with a link to its detail page

**Individual service pages:** `docs/wiki/services/<ct-name>/<service>.md`
- Instance table (port, config path, UID/GID, URL, Komodo stack name)
- Any service-specific configuration notes

### 6. Update the master index

Add entries to `docs/wiki/_master-index.md` for the new LXC and each service.

### 7. Update the global scheme docs

- `user-group-scheme.md` - Per-Service Users table + permissions table
- `lxc-idmap.md` - host users list
- `service-uid-exceptions.md` - any exceptions

### 8. Mirror everything to public repo

---

## Common Mistakes

**Skipping `add_user` for exception services.** The most common source of drift. The normalization rule says every reserved UID in the scheme must have a system user, regardless of whether the service uses it. No exceptions to this rule.

**Wrong host-side UID for exception services.** Calculate from the CT's idmap. UIDs 1000-1499 are 1:1. UIDs 0-999 get +100000. UIDs 1500+ get +100000 with offset.

**Forgetting to deploy the stack in the script.** A service without a `deploy_stack` call won't have its compose file copied on CT rebuild.

**Forgetting to mirror to the public repo.** Always update both repos in the same session.

**Adding a service without updating `lxc-idmap.md`.** The host-side users list is the reference for rebuilding the host from scratch. Keep it current.
