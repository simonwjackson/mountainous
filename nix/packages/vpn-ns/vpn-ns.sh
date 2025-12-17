#!/usr/bin/env bash

set -euo pipefail

# Auto-escalate to root if not already (for interactive use)
if [[ $EUID -ne 0 ]]; then
  if command -v sudo &>/dev/null; then
    exec sudo --preserve-env=VPN_NS_CONFIG,VPN_NS_LOCAL_NETS,VPN_NS_USER \
      "$0" "$@"
  else
    echo "ERROR: vpn-ns must be run as root (sudo not found)" >&2
    exit 1
  fi
fi

NS="vpn"
WG_IF="wg-vpn"
WG_CONF="${VPN_NS_CONFIG:-}"
RUN_AS_USER="${VPN_NS_USER:-${SUDO_USER:-}}"

# Veth pair for local network access
VETH_HOST="veth-vpn-host"
VETH_NS="veth-vpn-ns"
VETH_HOST_IP="10.200.200.1/24"
VETH_NS_IP="10.200.200.2/24"

usage() {
  cat <<EOF
Usage: vpn-ns [--setup|--cleanup] <command> [args...]

Run any command inside a WireGuard VPN namespace.
Internet traffic goes through VPN, but local networks remain accessible.
Multiple apps share the same namespace - cleanup happens when last app exits.
Auto-escalates to root via sudo when needed.

Options:
  --setup    Only ensure namespace exists, don't run a command (for systemd)
  --cleanup  Tear down namespace and all associated resources (for systemd)

Examples:
  vpn-ns curl ifconfig.me
  vpn-ns transmission-gtk
  vpn-ns --setup                   # Just create namespace
  vpn-ns --cleanup                 # Tear down namespace

Local access:
  Apps binding to 0.0.0.0 are reachable at 10.200.200.2
  192.168.x.x networks route through host (not VPN)

Environment variables:
  VPN_NS_CONFIG      Path to WireGuard config (required for --setup)
  VPN_NS_USER        User to run command as (default: invoking user)
  VPN_NS_LOCAL_NETS  Space-separated CIDRs for local routing (default: 192.168.0.0/16)
EOF
  exit 1
}

SETUP_ONLY=false
CLEANUP_ONLY=false
if [[ "${1:-}" == "--setup" ]]; then
  SETUP_ONLY=true
  shift
elif [[ "${1:-}" == "--cleanup" ]]; then
  CLEANUP_ONLY=true
  shift
fi

if [[ $# -eq 0 && "$SETUP_ONLY" == "false" && "$CLEANUP_ONLY" == "false" ]]; then
  usage
fi

# Handle cleanup mode early (doesn't need VPN_NS_CONFIG)
if [[ "$CLEANUP_ONLY" == "true" ]]; then
  echo "Cleaning up VPN namespace..."
  iptables -t nat -D POSTROUTING -s 10.200.200.0/24 ! -o "$VETH_HOST" -j MASQUERADE 2>/dev/null || true
  ip route del "${VETH_NS_IP%/*}/32" dev "$VETH_HOST" 2>/dev/null || true
  ip link del "$VETH_HOST" 2>/dev/null || true
  ip netns del "$NS" 2>/dev/null || true
  rm -rf "/etc/netns/$NS" 2>/dev/null || true
  echo "VPN namespace cleaned up"
  exit 0
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

namespace_ready() {
  ip netns list 2>/dev/null | grep -q "^$NS" || return 1
  ip netns exec "$NS" ip link show "$WG_IF" &>/dev/null || return 1
  ip netns exec "$NS" ip link show "$VETH_NS" &>/dev/null || return 1
  return 0
}

# Wait for DNS resolution of VPN endpoint (infinite retry with capped exponential backoff)
wait_for_dns() {
  local endpoint
  endpoint=$(grep -i "^Endpoint" "$WG_CONF" | head -1 | sed 's/.*=\s*//' | cut -d: -f1 | tr -d ' ')

  if [[ -z "$endpoint" ]]; then
    echo "WARNING: No Endpoint found in config, skipping DNS wait"
    return 0
  fi

  # Check if it's already an IP address (no DNS needed)
  if [[ "$endpoint" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Endpoint is IP address, no DNS resolution needed"
    return 0
  fi

  local delay=1
  local max_delay=60

  echo "Waiting for DNS resolution of $endpoint..."
  while ! getent hosts "$endpoint" &>/dev/null; do
    echo "DNS not ready for $endpoint, retrying in ${delay}s..."
    sleep "$delay"
    delay=$((delay * 2))
    ((delay > max_delay)) && delay=$max_delay
  done

  echo "DNS resolved: $endpoint"
}

# Health check loop for daemon mode (runs forever until tunnel dies)
health_loop() {
  local failures=0
  local max_failures=3
  local check_interval=60

  echo "Starting health check loop (interval: ${check_interval}s, max failures: $max_failures)"

  while true; do
    sleep "$check_interval"

    if ip netns exec "$NS" ping -c1 -W5 1.1.1.1 &>/dev/null; then
      if ((failures > 0)); then
        echo "VPN health restored after $failures failed check(s)"
        failures=0
      fi
    else
      ((failures++))
      echo "VPN health check failed ($failures/$max_failures)"

      if ((failures >= max_failures)); then
        echo "VPN tunnel appears dead, exiting for systemd restart"
        exit 1
      fi
    fi
  done
}

cleanup() {
  local pids
  pids=$(ip netns pids "$NS" 2>/dev/null | grep -v "^$$\$" || true)

  if [[ -n "$pids" ]]; then
    echo "Other processes still using namespace, skipping cleanup"
    return
  fi

  echo "Cleaning up namespace..."
  iptables -t nat -D POSTROUTING -s 10.200.200.0/24 ! -o "$VETH_HOST" -j MASQUERADE 2>/dev/null || true
  ip route del "${VETH_NS_IP%/*}/32" dev "$VETH_HOST" 2>/dev/null || true
  ip link del "$VETH_HOST" 2>/dev/null || true
  ip netns del "$NS" 2>/dev/null || true
  rm -rf "/etc/netns/$NS" 2>/dev/null || true
}

setup_namespace() {
  if ! ip netns list | grep -q "^$NS"; then
    echo "Creating network namespace '$NS'..."
    ip netns add "$NS"
  fi

  ip link del "$WG_IF" 2>/dev/null || true

  echo "Setting up WireGuard interface..."
  ip link add "$WG_IF" type wireguard

  local tmpconf stripped
  tmpconf=$(mktemp --suffix=.conf)
  cp "$WG_CONF" "$tmpconf"

  stripped=$(mktemp)
  wg-quick strip "$tmpconf" >"$stripped"
  wg setconf "$WG_IF" "$stripped"
  rm -f "$tmpconf" "$stripped"

  ip link set "$WG_IF" netns "$NS"

  ip netns exec "$NS" ip addr add "$WG_ADDR" dev "$WG_IF"
  ip netns exec "$NS" ip link set lo up
  ip netns exec "$NS" ip link set "$WG_IF" up
  ip netns exec "$NS" ip route add default dev "$WG_IF"

  echo "Setting up local network bridge..."
  ip link del "$VETH_HOST" 2>/dev/null || true
  ip link add "$VETH_HOST" type veth peer name "$VETH_NS"
  ip link set "$VETH_NS" netns "$NS"

  ip addr add "$VETH_HOST_IP" dev "$VETH_HOST"
  ip link set "$VETH_HOST" up

  ip netns exec "$NS" ip addr add "$VETH_NS_IP" dev "$VETH_NS"
  ip netns exec "$NS" ip link set "$VETH_NS" up

  local local_nets="${VPN_NS_LOCAL_NETS:-192.168.0.0/16}"
  for net in $local_nets; do
    ip netns exec "$NS" ip route add "$net" via "${VETH_HOST_IP%/*}" dev "$VETH_NS" 2>/dev/null || true
  done

  sysctl -w net.ipv4.ip_forward=1 >/dev/null

  ip route add "${VETH_NS_IP%/*}/32" dev "$VETH_HOST" 2>/dev/null || true
  iptables -t nat -A POSTROUTING -s 10.200.200.0/24 ! -o "$VETH_HOST" -j MASQUERADE 2>/dev/null || true

  mkdir -p "/etc/netns/$NS"
  echo "nameserver $WG_DNS" >"/etc/netns/$NS/resolv.conf"

  echo "VPN namespace ready (VPN: $WG_ADDR, Local: ${VETH_NS_IP%/*}, DNS: $WG_DNS)"
}

verify_vpn() {
  echo "Verifying VPN connection..."
  local vpn_ip
  vpn_ip=$(ip netns exec "$NS" curl -s --max-time 10 ifconfig.me 2>/dev/null) || {
    echo "ERROR: VPN connection failed. Aborting to prevent leak."
    exit 1
  }

  if [[ -z "$vpn_ip" ]]; then
    echo "ERROR: Could not verify VPN IP. Aborting to prevent leak."
    exit 1
  fi

  echo "VPN IP: $vpn_ip"
}

# Signal handler for clean shutdown in daemon mode
shutdown_handler() {
  echo "Received shutdown signal, exiting gracefully..."
  exit 0
}

# Only cleanup on exit if running a command (not setup-only/daemon mode)
# In daemon mode, ExecStop handles cleanup
if [[ "$SETUP_ONLY" == "false" ]]; then
  trap cleanup EXIT
fi

if namespace_ready; then
  echo "Reusing existing VPN namespace"
else
  # Wait for DNS before attempting setup
  wait_for_dns
  setup_namespace
  verify_vpn
fi

# If setup-only (daemon) mode, enter health check loop
if [[ "$SETUP_ONLY" == "true" ]]; then
  echo "Namespace '$NS' is ready for use, entering daemon mode"
  # Trap signals for clean shutdown
  trap shutdown_handler SIGTERM SIGINT
  health_loop
  # health_loop only returns on failure, which means exit 1 already called
fi

echo "Running: $*"
if [[ -n "$RUN_AS_USER" ]]; then
  ip netns exec "$NS" runuser -u "$RUN_AS_USER" -- \
    env DISPLAY="${DISPLAY:-}" \
    WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
    XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}" \
    DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-}" \
    HOME="${HOME:-/home/$RUN_AS_USER}" \
    "$@"
else
  ip netns exec "$NS" "$@"
fi
