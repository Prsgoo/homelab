#!/bin/bash
# Shared helpers - source this file, don't run it directly.
# Usage in CT scripts: source "$(dirname "$0")/common.sh"

PERIPHERY_VERSION="${PERIPHERY_VERSION:-latest}"

# Absolute path to the repo root (one level up from scripts/).
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ct_exists()  { pct status "$1" &>/dev/null; }
ct_running() { pct status "$1" 2>/dev/null | grep -q running; }

add_group() {
    local gid=$1 name=$2
    if getent group "$name" &>/dev/null; then
        echo "  skip group $name (exists)"
    else
        groupadd -g "$gid" "$name" && echo "  created group $name GID $gid"
    fi
}

add_user() {
    local uid=$1 gid=$2 name=$3
    if id "$name" &>/dev/null; then
        echo "  skip user $name (exists)"
    else
        useradd -u "$uid" -g "$gid" -s /bin/false -d /nonexistent "$name"
        echo "  created user $name UID $uid GID $gid"
    fi
}

patch_conf() {
    local vmid=$1 marker=$2 block=$3
    local conf="/etc/pve/lxc/$vmid.conf"
    if grep -qF "$marker" "$conf" 2>/dev/null; then
        echo "  CT $vmid: skip - $marker already present"
    else
        printf '\n%s\n' "$block" >> "$conf"
        echo "  CT $vmid: patched ($marker)"
    fi
}

set_mp() {
    local vmid=$1; shift
    local conf="/etc/pve/lxc/$vmid.conf"
    local host_path="${1%%,*}"
    if grep -qF "$host_path" "$conf" 2>/dev/null; then
        echo "  CT $vmid: skip - $host_path already present"
    else
        pct set "$vmid" "$@"
        echo "  CT $vmid: $*"
    fi
}

wait_for_boot() {
    local vmid=$1
    echo "  waiting for CT $vmid to boot..."
    local i
    for i in $(seq 1 30); do
        if pct exec "$vmid" -- systemctl is-active basic.target &>/dev/null; then
            echo "  CT $vmid ready"
            return 0
        fi
        sleep 2
    done
    echo "ERROR: CT $vmid did not boot within 60s" >&2
    return 1
}

# load_env: source scripts/.env into the current environment.
# Call once at the top of each CT script, before deploy_stack.
load_env() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local env_file="$script_dir/.env"
    if [ -f "$env_file" ]; then
        set -a
        # shellcheck disable=SC1090
        source "$env_file"
        set +a
    else
        echo "WARNING: $env_file not found" >&2
        echo "         Copy .env.example to .env and fill in all values." >&2
    fi
}

# deploy_stack <host_stack_dir> <compose_name> [var1 var2 ...]
# Creates the stack dir, copies compose.yaml from the repo, writes .env and .env.example.
# <compose_name> is relative to stacks/ in the repo root (e.g. "iot", "management/traefik").
# Var values are read from the environment - call load_env before deploy_stack.
deploy_stack() {
    local stack_dir=$1 compose_name=$2; shift 2
    local compose_src="$REPO_ROOT/stacks/$compose_name/compose.yaml"

    mkdir -p "$stack_dir"

    if [ -f "$compose_src" ]; then
        cp "$compose_src" "$stack_dir/compose.yaml"
    else
        echo "  WARNING: $(basename "$stack_dir"): compose not found at stacks/$compose_name/compose.yaml" >&2
    fi

    if [ $# -eq 0 ]; then
        printf '# No secrets. No .env file is required.\n' > "$stack_dir/.env.example"
        echo "  $(basename "$stack_dir"): ready (no secrets)"
        return
    fi

    : > "$stack_dir/.env.example"
    : > "$stack_dir/.env"
    local missing=()
    for var in "$@"; do
        printf '%s=\n' "$var" >> "$stack_dir/.env.example"
        local val="${!var:-}"
        [ -z "$val" ] && missing+=("$var")
        printf '%s=%s\n' "$var" "$val" >> "$stack_dir/.env"
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo "  WARNING: $(basename "$stack_dir"): missing vars: ${missing[*]}" >&2
    fi
    echo "  $(basename "$stack_dir"): ready ($# vars)"
}

# install_periphery <vmid> [root_directory]
# Requires: KOMODO_CORE_ADDR env var (loaded from .env via load_env).
# root_directory is required for Docker CTs (where Komodo manages stacks).
# Omit for native CTs (game-panel, pihole, wings).
install_periphery() {
    local vmid=$1 root_dir="${2:-}"
    local core_addr="${KOMODO_CORE_ADDR:?KOMODO_CORE_ADDR not set - check scripts/.env}"

    local version_arg=""
    [ "$PERIPHERY_VERSION" != "latest" ] && version_arg="--version $PERIPHERY_VERSION"

    echo "  installing Periphery on CT $vmid (core: $core_addr)"
    [ -n "$root_dir" ] && echo "  root_directory: $root_dir"

    cat > "/tmp/periphery-install-${vmid}.sh" << SCRIPT
#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl python3

curl -fsSL https://raw.githubusercontent.com/moghtech/komodo/main/scripts/setup-periphery.py \
    | python3 - $version_arg${root_dir:+ --root_directory $root_dir}

mkdir -p /etc/komodo
cat > /etc/komodo/periphery.config.toml << TOML
[periphery]
port = 8120

[core]
addresses = ["$core_addr"]
TOML

mkdir -p /etc/systemd/system/periphery.service.d
cat > /etc/systemd/system/periphery.service.d/env.conf << DROPIN
[Service]
Environment=PERIPHERY_CONFIG_PATH=/etc/komodo/periphery.config.toml
$([ -n "$root_dir" ] && echo "Environment=PERIPHERY_ROOT_DIRECTORY=$root_dir")
DROPIN

systemctl daemon-reload
systemctl enable --now periphery
systemctl is-active periphery && echo "  periphery running" || { echo "ERROR: periphery not active" >&2; exit 1; }
SCRIPT

    pct push "$vmid" "/tmp/periphery-install-${vmid}.sh" /tmp/periphery-install.sh
    pct exec "$vmid" -- bash /tmp/periphery-install.sh
    rm -f "/tmp/periphery-install-${vmid}.sh"
}

# configure_docker_daemon <vmid>
# Sets log-driver=journald and mtu=1450. Call after the CT is running.
# CT 100 (management) is excluded - it needs userland-proxy:false too and is
# configured manually in the Komodo guide since Periphery runs inside Docker there.
configure_docker_daemon() {
    local vmid=$1
    pct exec "$vmid" -- bash -c 'mkdir -p /etc/docker && cat > /etc/docker/daemon.json << '"'"'EOF'"'"'
{
  "log-driver": "journald",
  "mtu": 1450
}
EOF
systemctl restart docker'
    echo "  CT $vmid: Docker daemon configured"
}

start_and_install_periphery() {
    local vmid=$1 root_dir="${2:-}"

    echo ""
    echo "=== Starting CT $vmid ==="
    if ct_running "$vmid"; then
        echo "  already running"
    else
        pct start "$vmid"
        wait_for_boot "$vmid"
    fi

    echo ""
    echo "=== Periphery ==="
    install_periphery "$vmid" "$root_dir"
}
