#!/usr/bin/env bash

set -euo pipefail

NS="vpn"
WG_IF="wg-vpn"
WG_CONF="${VPN_NS_CONFIG:-}"

usage() {
    echo "Usage: vpn-ns <command> [args...]"
    echo ""
    echo "Run any command inside a WireGuard VPN namespace."
    echo ""
    echo "Examples:"
    echo "  vpn-ns curl ifconfig.me"
    echo "  vpn-ns transmission-gtk"
    echo "  vpn-ns nix run nixpkgs#someapp -- --some-flags"
    echo ""
    echo "Environment variables:"
    echo "  VPN_NS_CONFIG  Path to WireGuard config (required)"
    exit 1
}

if [[ $# -eq 0 ]]; then
    usage
fi

if [[ -z "$WG_CONF" ]]; then
    echo "ERROR: VPN_NS_CONFIG environment variable not set"
    echo "Set it to the path of your WireGuard configuration file"
    exit 1
fi

if [[ ! -f "$WG_CONF" ]]; then
    echo "ERROR: WireGuard config not found: $WG_CONF"
    exit 1
fi

# Parse Address and DNS from WireGuard config
WG_ADDR=$(grep -i "^Address" "$WG_CONF" | head -1 | sed 's/.*=\s*//' | tr -d ' ')
WG_DNS=$(grep -i "^DNS" "$WG_CONF" | head -1 | sed 's/.*=\s*//' | tr -d ' ' | cut -d',' -f1)

if [[ -z "$WG_ADDR" ]]; then
    echo "ERROR: Could not parse Address from WireGuard config"
    exit 1
fi

if [[ -z "$WG_DNS" ]]; then
    echo "WARNING: No DNS found in config, using 1.1.1.1"
    WG_DNS="1.1.1.1"
fi

cleanup() {
    echo "Cleaning up..."
    sudo ip netns del "$NS" 2>/dev/null || true
    sudo rm -rf "/etc/netns/$NS" 2>/dev/null || true
}

setup_namespace() {
    # Create namespace if it doesn't exist
    if ! ip netns list | grep -q "^$NS"; then
        echo "Creating network namespace '$NS'..."
        sudo ip netns add "$NS"
    fi

    # Remove existing interface if present
    sudo ip link del "$WG_IF" 2>/dev/null || true

    # Create and configure WireGuard interface
    echo "Setting up WireGuard interface..."
    sudo ip link add "$WG_IF" type wireguard

    # Copy config to temp file with .conf extension (wg-quick requires it)
    local tmpconf
    tmpconf=$(mktemp --suffix=.conf)
    cp "$WG_CONF" "$tmpconf"

    # Strip wg-quick specific options and configure interface
    local stripped
    stripped=$(mktemp)
    wg-quick strip "$tmpconf" > "$stripped"
    sudo wg setconf "$WG_IF" "$stripped"
    rm -f "$tmpconf" "$stripped"

    sudo ip link set "$WG_IF" netns "$NS"

    # Configure interface inside namespace
    sudo ip netns exec "$NS" ip addr add "$WG_ADDR" dev "$WG_IF"
    sudo ip netns exec "$NS" ip link set lo up
    sudo ip netns exec "$NS" ip link set "$WG_IF" up
    sudo ip netns exec "$NS" ip route add default dev "$WG_IF"

    # Configure DNS for the namespace
    sudo mkdir -p "/etc/netns/$NS"
    echo "nameserver $WG_DNS" | sudo tee "/etc/netns/$NS/resolv.conf" > /dev/null

    echo "VPN namespace ready (Address: $WG_ADDR, DNS: $WG_DNS)"
}

verify_vpn() {
    echo "Verifying VPN connection..."
    local vpn_ip
    vpn_ip=$(sudo ip netns exec "$NS" curl -s --max-time 10 ifconfig.me 2>/dev/null) || {
        echo "ERROR: VPN connection failed. Aborting to prevent leak."
        exit 1
    }

    if [[ -z "$vpn_ip" ]]; then
        echo "ERROR: Could not verify VPN IP. Aborting to prevent leak."
        exit 1
    fi

    echo "VPN IP: $vpn_ip"
}

trap cleanup EXIT

setup_namespace
verify_vpn

echo "Running: $*"
sudo ip netns exec "$NS" sudo -u "$USER" \
    DISPLAY="${DISPLAY:-}" \
    WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
    XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}" \
    DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-}" \
    HOME="$HOME" \
    "$@"
