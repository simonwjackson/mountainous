#!/usr/bin/env bash
export NIX_SSHOPTS="-A"

hosts="$1"
ssh_port="22"
shift

if [ -z "$hosts" ]; then
  hosts=$(nix flake show --json | nix run nixpkgs\#jq -- --raw-output '.nixosConfigurations | keys | join(",")')
fi

# Iterate over each host
for host in ${hosts//,/ }; do
  if nc -w 1 -z "${host}" "${ssh_port}" >/dev/null 2>&1; then
    nixos-rebuild \
      --flake ".#$host" \
      switch \
      --target-host "$host" \
      --build-host "zao" \
      --use-remote-sudo \
      --use-substitutes \
      "$@"
    # --log-format internal-json -v |& nix run nixpkgs\#nix-output-monitor -- --json "$@"
  else
    offline_hosts+=("$host")
  fi
done
