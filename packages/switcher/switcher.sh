ACTION="${1:-}"
HOSTNAME="${2:-}"
BUILD_HOSTS="${3:-}"

if [ -z "$BUILD_HOSTS" ]; then
  BUILD_HOSTS=$(nix flake show --json | nix run nixpkgs\#jq -- --raw-output '.nixosConfigurations | keys | join(",")')
fi

if [ "$(uname)" == "Darwin" ]; then
  sudo nix run nix-darwin \
    -- "${ACTION}" --flake ".#$HOSTNAME"
else
  # Convert comma-separated hosts to an array
  IFS=',' read -ra HOSTS_ARRAY <<<"$HOSTNAME"
  IFS=',' read -ra BUILD_HOSTS_ARRAY <<<"$BUILD_HOSTS"

  # Check the status of each host and add online hosts to the builders list
  BUILDERS=""
  OFFLINE_HOSTS=()
  OFFLINE_BUILD_HOSTS=()
  for host in "${BUILD_HOSTS_ARRAY[@]}"; do
    if ssh -o ConnectTimeout=1 "$host" "exit"; then
      # TODO: Setup dedicated builder
      BUILDERS+="$(whoami)@$host "
    else
      OFFLINE_BUILD_HOSTS+=("$host")
    fi
  done

  # If any builder is online and localhost is on battery power, do not build locally
  BUILD_LOCALLY="auto"
  # FIX: Battery check isnt working
  # if [ -n "$BUILDERS" ]; then
  #   if nix run nixpkgs\#acpi &>/dev/null; then
  #     if nix run nixpkgs\#acpi -- -a | grep -q 'off-line'; then
  #       BUILD_LOCALLY="0"
  #     fi
  #   fi
  # fi

  # Switch each host and keep track of successful and offline hosts
  SWITCHED_HOSTS=()

  for host in "${HOSTS_ARRAY[@]}"; do
    if ssh -o ConnectTimeout=1 "$host" "exit"; then
      nixos-rebuild "${ACTION}" \
        --flake ".#$host" \
        --target-host "$host" \
        --builders "$BUILDERS" \
        --use-remote-sudo \
        --use-substitutes \
        --max-jobs "$BUILD_LOCALLY" \
        --log-format internal-json -v |& nix run nixpkgs\#nix-output-monitor -- --json

      SWITCHED_HOSTS+=("$host")
    else
      OFFLINE_HOSTS+=("$host")
    fi
  done

  # Print summary of offline and switched hosts
  echo "Offline Hosts: ${OFFLINE_HOSTS[*]}"
  echo "Offline Build Hosts: ${OFFLINE_BUILD_HOSTS[*]}"
  echo "Successfully Switched Hosts: ${SWITCHED_HOSTS[*]}"
fi
