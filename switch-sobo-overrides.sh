#!/usr/bin/env bash
set -euo pipefail

# Switch sobo by building on fuji, activating on sobo, and overriding the
# local development inputs used by the sobo guest configuration.
#
# Override these env vars if your local checkouts live somewhere else:
#   NIX_ON_ROCKS_GUEST=/path/to/nix-on-rocks/guest
#   KORRI=/path/to/korri

NIX_ON_ROCKS_GUEST="${NIX_ON_ROCKS_GUEST:-/home/simonwjackson/code/sandbox/nix-on-rocks/guest}"
KORRI="${KORRI:-/home/simonwjackson/code/sandbox/korri}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ssh_tmpdir="$(mktemp -d)"
trap 'rm -rf "${ssh_tmpdir}"' EXIT

# nixos-rebuild uses NIX_SSHOPTS for both activation SSH and nix-copy SSH.
# Keep fuji on the normal SSH config, but force sobo to the nspawn guest sshd
# on :2222 and verify it against the checked-in host RSA key.
awk '{ print "[sobo]:2222 " $1 " " $2 }' \
  "${REPO_ROOT}/secrets/keys/hosts/aarch64-linux_sobo_ssh_host_rsa_key.pub" \
  > "${ssh_tmpdir}/known_hosts"
cat > "${ssh_tmpdir}/ssh_config" <<EOF
Host sobo
  HostName sobo
  Port 2222
  UserKnownHostsFile ${ssh_tmpdir}/known_hosts
  StrictHostKeyChecking yes

Include ~/.ssh/config
EOF

NIX_SSHOPTS="-F ${ssh_tmpdir}/ssh_config ${NIX_SSHOPTS:-}" \
  nixos-rebuild switch \
  --flake .#sobo \
  --override-input nix-on-rocks-guest "path:${NIX_ON_ROCKS_GUEST}" \
  --override-input korri "path:${KORRI}" \
  --build-host fuji \
  --target-host root@sobo
