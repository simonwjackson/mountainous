#!/usr/bin/env bash

set -euo pipefail

# Constants
DEFAULT_ARCH="x86_64-linux"
DEFAULT_USERNAME="simonwjackson"
STATE_VERSION="24.11"
BASE_DIR="$(git rev-parse --show-toplevel)"

# Usage function
show_usage() {
  echo "Usage: scaffold [username@]<system-name> <ip> [--arch <architecture>]"
  echo "Default architecture: $DEFAULT_ARCH"
  echo "Default username: $DEFAULT_USERNAME"
  exit 1
}

# Create directory and file with content
create_config() {
  local dir="$1"
  local file="$2"
  local content="$3"

  mkdir -p "$dir"
  echo "$content" >"$file"
}

# Parse username and system name
parse_system_arg() {
  local arg="$1"
  local username_var="$2"
  local system_var="$3"

  if [[ "$arg" == *"@"* ]]; then
    printf -v "$username_var" "%s" "${arg%%@*}"
    printf -v "$system_var" "%s" "${arg#*@}"
  else
    printf -v "$username_var" "%s" "$DEFAULT_USERNAME"
    printf -v "$system_var" "%s" "$arg"
  fi
}

# Validate arguments
if [ $# -lt 2 ] || [ $# -gt 4 ]; then
  show_usage
fi

USERNAME=""
SYSTEM_NAME=""
parse_system_arg "$1" USERNAME SYSTEM_NAME
IP="$2"
ARCH="$DEFAULT_ARCH"

# Parse optional arguments
shift 2
while [[ $# -gt 0 ]]; do
  case $1 in
  --arch)
    ARCH="$2"
    shift 2
    ;;
  *)
    echo "Unknown argument: $1"
    exit 1
    ;;
  esac
done

# System configuration template
SYSTEM_CONFIG=$(
  cat <<EOF
{
  modulesPath,
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.mountainous) enabled disabled;
in {
  imports = [

  ];

  mountainous = {
    boot = enabled;
    gaming = {
      core = disabled;
      steam = disabled;
    };
    impermanence = enabled;
    # networking.core.names = [
    #   {
    #     name = "wifi";
    #     mac = "00:00:00:00:00:00";
    #   }
    # ];
    profiles = {
      laptop = disabled;
      workstation = enabled;
    };
    # TODO: encrypt generated syncthing keys
    syncthing = {
      # key = config.age.secrets.$SYSTEM_NAME-syncthing-key.path;
      # cert = config.age.secrets.$SYSTEM_NAME-syncthing-cert.path;
    };
  };

  system.stateVersion = "$STATE_VERSION";
}
EOF
)

# Home configuration template
HOME_CONFIG=$(
  cat <<'EOF'
{ config, lib, pkgs, ... }:

{
  imports = [

  ];

  home = {
    homeDirectory = "/home/\${config.home.username}";
    stateVersion = "$STATE_VERSION"; # WARN: Changing this might break things. Just leave it.
  };
}
EOF
)

# Syncthing configuration template
SYNCTHING_CONFIG=$(
  cat <<EOF
{
  config,
  host,
  ...
}: {
  device = {
    # TODO: Add your syncthing device id here
    id = "0000000-0000000-0000000-0000000-0000000-0000000-0000000-0000000";
    name = "(\${host})";
  };
  shares = {
    # TODO: Add your syncthing shares here
    #  shareName= {
    #   path = "/path/to/share";
    #   type = "sendreceive";
    # };
  };
}
EOF
)

# Create system configuration
create_config \
  "$BASE_DIR/systems/$ARCH/$SYSTEM_NAME" \
  "$BASE_DIR/systems/$ARCH/$SYSTEM_NAME/default.nix" \
  "$SYSTEM_CONFIG"

# Create home configuration
create_config \
  "$BASE_DIR/homes/$ARCH/$USERNAME@$SYSTEM_NAME" \
  "$BASE_DIR/homes/$ARCH/$USERNAME@$SYSTEM_NAME/default.nix" \
  "$HOME_CONFIG"

# Create syncthing configuration
create_config \
  "$BASE_DIR/systems/$ARCH/$SYSTEM_NAME" \
  "$BASE_DIR/systems/$ARCH/$SYSTEM_NAME/syncthing.nix" \
  "$SYNCTHING_CONFIG"

echo "Successfully scaffolded system and home for $USERNAME@$SYSTEM_NAME with architecture $ARCH"
echo
echo "TODOs:"
echo "1. Add your syncthing device ID in systems/$ARCH/$SYSTEM_NAME/syncthing.nix"
echo "2. Configure your syncthing shares in systems/$ARCH/$SYSTEM_NAME/syncthing.nix"
echo "3. Configure syncthing keys in systems/$ARCH/$SYSTEM_NAME/default.nix"
echo 
echo "Warning: you need to run the following command inside your secrets repo:"
echo "1 ./get-pub-key.sh $SYSTEM_NAME $IP"
echo "2. Commit and push your changes in the secrets repo"
echo "3. Run 'just up secrets' to update your secrets"
