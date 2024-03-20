#!/usr/bin/env bash
export NIX_SSHOPTS="-A"

hosts="$1"
shift

if [ -z "$hosts" ]; then
  hosts="$(hostname)"
else
  # Get the list of NixOS host names from flake.nix
  hosts=$(cat ./flake.nix | grep ' = mkSystem ' | awk -F ' ' '{print $1}' | awk '{printf $0 ",";}')
fi

# Iterate over each host
for host in ${hosts//,/ }; do
  if nix store ping --store "ssh://$host" >/dev/null 2>&1; then
    nixos-rebuild \
      --flake ".#$host" \
      switch \
      --target-host "$host" \
      --use-remote-sudo \
      --use-substitutes \
      "$@" \
      --log-format internal-json -v |& nom --json
  else
    offline_hosts+=("$host")
  fi
done
