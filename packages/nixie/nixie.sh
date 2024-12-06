#!/usr/bin/env bash

set -euo pipefail

doc="Nixer Script

Usage:
  $(basename "$0") <action> [host1,...] [options]
  $(basename "$0") -h | --help

Arguments:
  <action>               Action supported by nixos-rebuild (switch, test, build, etc)
  [host1,host2,...]      Optional: List of hosts. If blank, defaults to the NIXIE_HOSTS environment variable or the current machine.

Options:
  -h, --help             Show this screen.
  --[no-]local-build     Use local build (default: --local-build)
  --[no-]check-battery   Check if builders are on battery power (default: --check-battery)
  --[no-]update          Run 'nix flake update' before building (default: --no-update)
  --[no-]report          Generate and display a summary report (default: --report)
  --builders             Comma-separated list of builders to use
  [extra options]        All other options are passed to the final command.

Environment Variables:
  NIXIE_HOSTS                  Comma-separated list of hosts to build for. Used if no hosts are specified.
  NIXIE_BUILDERS        Comma-separated list of builders to use. Used if no builders are specified.
"

ACTION=""
HOSTS_ARG=""
HOSTS_ENV="${NIXIE_HOSTS:-}"
HOSTS_ARRAY=()
ONLINE_HOSTS=()
OFFLINE_HOSTS=()
LOCAL_BUILD=true
CHECK_BATTERY=true
UPDATE_FLAKE=false
GENERATE_REPORT=true
EXTRA_OPTS=()
BUILDERS_ARRAY=()
SHOULD_EXIT=false
SUCCESSFUL_HOSTS=()
FAILED_HOSTS=()

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
    --local-build)
      LOCAL_BUILD=true
      shift
      ;;
    --no-local-build)
      LOCAL_BUILD=false
      shift
      ;;
    --check-battery)
      CHECK_BATTERY=true
      shift
      ;;
    --no-check-battery)
      CHECK_BATTERY=false
      shift
      ;;
    --update)
      UPDATE_FLAKE=true
      shift
      ;;
    --no-update)
      UPDATE_FLAKE=false
      shift
      ;;
    --report)
      GENERATE_REPORT=true
      shift
      ;;
    --no-report)
      GENERATE_REPORT=false
      shift
      ;;
    --builders)
      IFS=',' read -ra BUILDERS_ARRAY <<<"$2"
      shift 2
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

  # If no builders specified, use the BUILDERS environment variable or the current host
  if [[ ${#BUILDERS_ARRAY[@]} -eq 0 ]]; then
    if [[ -n "${NIXIE_BUILDERS:-}" ]]; then
      IFS=',' read -ra BUILDERS_ARRAY <<<"$NIXIE_BUILDERS"
    else
      mapfile -t BUILDERS_ARRAY < <(hostname)
    fi
  fi
}

parse_hosts() {
  if [[ -n "${HOSTS_ARG:-}" ]]; then
    IFS=',' read -ra HOSTS_ARRAY <<<"$HOSTS_ARG"
  elif [[ -n "$HOSTS_ENV" ]]; then
    IFS=',' read -ra HOSTS_ARRAY <<<"$HOSTS_ENV"
  else
    read -ra HOSTS_ARRAY <<<"$(hostname)"
  fi
}

check_host_online() {
  local host=$1
  if ssh -o ConnectTimeout=1 -o BatchMode=yes -o StrictHostKeyChecking=no "$host" exit 2>/dev/null; then
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

check_builders_online() {
  log info "Checking which builders are online..."

  # Handle GNU Parallel citation notice
  if [ ! -f ~/.parallel/will-cite ]; then
    mkdir -p ~/.parallel
    touch ~/.parallel/will-cite
  fi

  mapfile -t ONLINE_BUILDERS < <(parallel -j0 check_host_online ::: "${BUILDERS_ARRAY[@]}")
  mapfile -t OFFLINE_BUILDERS < <(comm -23 <(printf "%s\n" "${BUILDERS_ARRAY[@]}" | sort) <(printf "%s\n" "${ONLINE_BUILDERS[@]}" | sort))

  log info "Online builders: ${ONLINE_BUILDERS[*]}"
  if [[ ${#OFFLINE_BUILDERS[@]} -gt 0 ]]; then
    log warn "Offline builders: ${OFFLINE_BUILDERS[*]}"
  fi

  # Check if the only online builder is the local machine
  if [[ ${#ONLINE_BUILDERS[@]} -eq 1 && "${ONLINE_BUILDERS[0]}" == "$(hostname)" ]]; then
    ONLY_LOCAL_BUILDER=true
  else
    ONLY_LOCAL_BUILDER=false
  fi
}

check_battery() {
  local host=$1
  if ssh \
    -o ConnectTimeout=1 \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    "$host" \
    "nix run nixpkgs#acpi &>/dev/null && nix run nixpkgs#acpi -- -a | grep -q 'off-line'" 2>/dev/null; then
    echo "$host"
  fi
}
export -f check_battery

filter_battery_powered_builders() {
  if $CHECK_BATTERY; then
    log info "Checking which builders are on battery power..."
    mapfile -t BATTERY_POWERED_BUILDERS < <(parallel -j0 check_battery ::: "${ONLINE_BUILDERS[@]}")

    if [[ ${#BATTERY_POWERED_BUILDERS[@]} -gt 0 ]]; then
      log warn "Builders on battery power: ${BATTERY_POWERED_BUILDERS[*]}"

      # Remove battery-powered builders from ONLINE_BUILDERS
      mapfile -t ONLINE_BUILDERS < <(comm -23 <(printf "%s\n" "${ONLINE_BUILDERS[@]}" | sort) <(printf "%s\n" "${BATTERY_POWERED_BUILDERS[@]}" | sort))

      log info "Remaining builders for building: ${ONLINE_BUILDERS[*]}"
    else
      log info "No builders are on battery power."
    fi
  fi
}

run_action() {
  local host=$1
  log info "Running $ACTION on $host"

  local max_jobs_opt
  if $LOCAL_BUILD; then
    max_jobs_opt="auto"
  else
    max_jobs_opt="0"
  fi

  local builders_opt=()
  if [[ ${#ONLINE_BUILDERS[@]} -gt 0 ]]; then
    local builders_list
    builders_list=$(
      IFS=,
      echo "${ONLINE_BUILDERS[*]}"
    )
    builders_opt=(--builders "$builders_list")
  fi

  if nixos-rebuild "$ACTION" \
    --flake ".#$host" \
    --target-host "$host" \
    --use-remote-sudo \
    --use-substitutes \
    --max-jobs "$max_jobs_opt" \
    "${builders_opt[@]}" \
    "${EXTRA_OPTS[@]}" \
    --log-format internal-json -v |& nom --json; then
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
    "Nixer Script Summary"

  gum style --foreground 212 "Action performed: $ACTION"

  if $UPDATE_FLAKE; then
    gum style --foreground 212 "Flake update: Performed"
  else
    gum style --foreground 212 "Flake update: Skipped"
  fi

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

  gum style --foreground 212 "Build configuration:"
  gum style "  Local build: $(if $LOCAL_BUILD; then echo "Enabled"; else echo "Disabled"; fi)"
  gum style "  Battery check: $(if $CHECK_BATTERY; then echo "Enabled"; else echo "Disabled"; fi)"

  gum style --foreground 212 "Builders used:"
  for builder in "${ONLINE_BUILDERS[@]}"; do
    gum style "  - $builder"
  done

  if [[ ${#BATTERY_POWERED_BUILDERS[@]} -gt 0 ]]; then
    gum style --foreground 212 "Builders on battery power (excluded):"
    for builder in "${BATTERY_POWERED_BUILDERS[@]}"; do
      gum style "  - $builder" --foreground 214
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
  check_hosts_online
  check_builders_online
  filter_battery_powered_builders

  if [[ ${#ONLINE_BUILDERS[@]} -eq 0 ]]; then
    log error "No builders are available for building. Exiting."
    exit 1
  fi

  if [[ "$ONLY_LOCAL_BUILDER" = true && "$LOCAL_BUILD" = false ]]; then
    log error "The only available builder is the local machine, but --no-local-build is set. Exiting."
    exit 1
  fi

  if $UPDATE_FLAKE; then
    log info "Updating flake..."
    if nix flake update; then
      log info "Flake updated successfully"
    else
      log error "Failed to update flake"
      exit 1
    fi
  fi

  for host in "${ONLINE_HOSTS[@]}"; do
    if $SHOULD_EXIT; then
      log warn "Script termination requested. Exiting."
      exit 1
    fi
    run_action "$host"
  done

  if $GENERATE_REPORT; then
    print_summary
  fi
}

main "$@"
