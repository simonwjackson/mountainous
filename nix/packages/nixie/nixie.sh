#!/usr/bin/env bash

set -euo pipefail

doc="nixie Script

Usage:
  $(basename "$0") <action> [host1,...] [options]
  $(basename "$0") -h | --help

Arguments:
  <action>               Action supported by nixos-rebuild (switch, test, build, etc)
  [host1,host2,...]      Optional: List of hosts. If blank, defaults to the current machine.

Options:
  -h, --help             Show this screen.
  --[no-]report          Generate and display a summary report (default: --report)
  [extra options]        All other options are passed to the final command.

Environment Variables:
  NIXIE_BUILDERS         Comma-separated list of builders to use for building (e.g., 'ssh://host1,ssh://host2')

"

ACTION=""
HOSTS_ARG=""
HOSTS_ARRAY=()
ONLINE_HOSTS=()
OFFLINE_HOSTS=()
GENERATE_REPORT=true
EXTRA_OPTS=()
SHOULD_EXIT=false
SUCCESSFUL_HOSTS=()
FAILED_HOSTS=()
BUILDERS_ENV="${NIXIE_BUILDERS:-}"
BUILDERS_SPEC=""

log() {
  gum log --level "$1" "$2"
}

handle_sigint() {
  log warn "Received SIGINT. Terminating all processes..."
  SHOULD_EXIT=true
  kill -TERM 0
  wait
  exit 1
}

trap handle_sigint SIGINT

parse_arguments() {
  if [[ $# -lt 1 ]]; then
    echo "$doc"
    exit 1
  fi

  # Check for help first
  if [[ $1 == "-h" || $1 == "--help" ]]; then
    echo "$doc"
    exit 0
  fi

  ACTION=$1
  shift

  # Initialize HOSTS_ARG as empty
  HOSTS_ARG=""

  while [[ $# -gt 0 ]]; do
    case $1 in
    -h | --help)
      echo "$doc"
      exit 0
      ;;
    --report)
      GENERATE_REPORT=true
      shift
      ;;
    --no-report)
      GENERATE_REPORT=false
      shift
      ;;
    --*)
      EXTRA_OPTS+=("$1")
      if [[ $# -gt 1 && ! $2 == --* ]]; then
        EXTRA_OPTS+=("$2")
        shift
      fi
      shift
      ;;
    *)
      if [[ -z "$HOSTS_ARG" ]]; then
        HOSTS_ARG=$1
      else
        echo "Unexpected argument: $1"
        echo "$doc"
        exit 1
      fi
      shift
      ;;
    esac
  done

}

parse_hosts() {
  if [[ -n "${HOSTS_ARG:-}" ]]; then
    IFS=',' read -ra HOSTS_ARRAY <<<"$HOSTS_ARG"
  else
    read -ra HOSTS_ARRAY <<<"$(hostname)"
  fi
}

parse_builders() {
  if [[ -n "${BUILDERS_ENV:-}" ]]; then
    # Convert comma-separated builders to space-separated format for nixos-rebuild
    BUILDERS_SPEC="${BUILDERS_ENV//,/ }"
    log info "Using builders: ${BUILDERS_SPEC}"
  fi
}

check_host_online() {
  local host=$1

  if ssh \
    -o ConnectTimeout=1 \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    "$host" exit 2>/dev/null; then
    echo "$host"
  fi
}
export -f check_host_online

check_hosts_online() {
  log info "Checking which hosts are online..."

  # Handle GNU Parallel citation notice
  if [ ! -f ~/.parallel/will-cite ]; then
    mkdir -p ~/.parallel
    touch ~/.parallel/will-cite
  fi

  mapfile -t ONLINE_HOSTS < <(parallel -j0 check_host_online ::: "${HOSTS_ARRAY[@]}")
  mapfile -t OFFLINE_HOSTS < <(comm -23 <(printf "%s\n" "${HOSTS_ARRAY[@]}" | sort) <(printf "%s\n" "${ONLINE_HOSTS[@]}" | sort))

  if [[ ${#ONLINE_HOSTS[@]} -eq 0 ]]; then
    log error "No hosts are online. Exiting."
    # exit 1
  fi

  log info "Online hosts: ${ONLINE_HOSTS[*]}"
  if [[ ${#OFFLINE_HOSTS[@]} -gt 0 ]]; then
    log warn "Offline hosts: ${OFFLINE_HOSTS[*]}"
  fi
}

run_action() {
  local host=$1
  log info "Running $ACTION on $host"

  # Build the nixos-rebuild command
  local cmd_args=(
    "$ACTION"
    --flake ".#$host"
    --target-host "$host"
    --use-remote-sudo
    --use-substitutes
    --max-jobs "auto"
  )

  # Add builders if specified
  if [[ -n "${BUILDERS_SPEC:-}" ]]; then
    cmd_args+=(--builders "${BUILDERS_SPEC}")
  fi

  # Add any extra options
  cmd_args+=("${EXTRA_OPTS[@]}")
  cmd_args+=(--log-format internal-json -v)

  if nixos-rebuild "${cmd_args[@]}" |& nom --json; then
    log info "Successfully ran $ACTION on $host"
    SUCCESSFUL_HOSTS+=("$host")
  else
    log error "Failed to run $ACTION on $host"
    FAILED_HOSTS+=("$host")
  fi
}

print_summary() {
  gum style \
    --border normal \
    --margin "1" \
    --padding "1" \
    --border-foreground 212 \
    "nixie Script Summary"

  gum style --foreground 212 "Action performed: $ACTION"

  gum style --foreground 212 "Hosts processed:"
  for host in "${ONLINE_HOSTS[@]}"; do
    if [[ " ${SUCCESSFUL_HOSTS[*]} " =~ ${host} ]]; then
      gum style "  ✓ $host" --foreground 46
    elif [[ " ${FAILED_HOSTS[*]} " =~ ${host} ]]; then
      gum style "  ✗ $host" --foreground 196
    else
      gum style "  ? $host" --foreground 214
    fi
  done

  if [[ ${#OFFLINE_HOSTS[@]} -gt 0 ]]; then
    gum style --foreground 212 "Offline hosts:"

    for host in "${OFFLINE_HOSTS[@]}"; do
      gum style "  - $host" --foreground 214
    done
  fi

  gum style --foreground 212 "Summary:"
  gum style "  Total hosts: ${#HOSTS_ARRAY[@]}"
  gum style "  Online hosts: ${#ONLINE_HOSTS[@]}"
  gum style "  Offline hosts: ${#OFFLINE_HOSTS[@]}"
  gum style "  Successful: ${#SUCCESSFUL_HOSTS[@]}"
  gum style "  Failed: ${#FAILED_HOSTS[@]}"
}

main() {
  parse_arguments "$@"
  parse_hosts
  parse_builders
  check_hosts_online

  for host in "${ONLINE_HOSTS[@]}"; do
    if "$SHOULD_EXIT"; then
      log warn "Script termination requested. Exiting."
      exit 1
    fi
    run_action "$host"
  done

  if "$GENERATE_REPORT"; then
    print_summary
  fi
}

main "$@"
