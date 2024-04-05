#!/usr/bin/env bash
export NIX_SSHOPTS="-A"

hosts="$1"
shift

if [ -z "$hosts" ]; then
  # Get the list of NixOS host names from flake.nix
  hosts=$(cat ./flake.nix | grep ' = mkSystem ' | awk -F ' ' '{print $1}' | awk '{printf $0 ",";}')
# else
#   hosts="$(hostname)"
fi

# Iterate over each host
for host in ${hosts//,/ }; do
  if nc -w 1 -z "${host}" 22 >/dev/null 2>&1; then
    nixos-rebuild \
      --flake ".#$host" \
      switch \
      --target-host "$host" \
      --use-remote-sudo \
      --use-substitutes \
      "$@"
    # --log-format internal-json -v |& nom --json
  else
    offline_hosts+=("$host")
  fi
done
