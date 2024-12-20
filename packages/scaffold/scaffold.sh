#!/usr/bin/env bash

set -euo pipefail

# Constants
DEFAULT_ARCH="x86_64-linux"
DEFAULT_USERNAME="simonwjackson"
STATE_VERSION="24.11"
BASE_DIR="$(git rev-parse --show-toplevel)"

# Usage function
show_usage() {
  echo "Usage: scaffold [username@]<system-name> [--arch <architecture>]"
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
if [ $# -lt 1 ] || [ $# -gt 3 ]; then
  show_usage
fi

USERNAME=""
SYSTEM_NAME=""
parse_system_arg "$1" USERNAME SYSTEM_NAME
ARCH="$DEFAULT_ARCH"

# Parse arguments
shift
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
{ lib, pkgs, ... }:

{
  imports = [

  ];

  home = {
    homeDirectory = "/home/${config.home.username}";
    stateVersion = "$STATE_VERSION"; # WARN: Changing this might break things. Just leave it.
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

echo "Successfully scaffolded system and home for $USERNAME@$SYSTEM_NAME with architecture $ARCH"
