############################################################################
#
#  Nix commands related to the local machine
#
############################################################################

# Default recipe
[private]
_default:
    @just --list --unsorted

NIXIE_EXTRA_ARGS := env_var_or_default("NIXIE_EXTRA_ARGS", "")

# Deploy configuration changes to systems
[group('deploy')]
switch *ARGS:
    nix run .#nixie -- switch {{ ARGS }} {{ NIXIE_EXTRA_ARGS }}

# Test configuration without applying
[group('deploy')]
test *ARGS:
    nix run .#nixie -- test {{ ARGS }} {{ NIXIE_EXTRA_ARGS }}

# Set configuration for next boot
[group('deploy')]
boot *ARGS:
    nix run .#nixie -- boot {{ ARGS }} {{ NIXIE_EXTRA_ARGS }}

# Build configuration (dry-run)
[group('deploy')]
build *ARGS:
    nix run .#nixie -- build {{ ARGS }} {{ NIXIE_EXTRA_ARGS }}

# Deploy a new system and home configuration
[group('deploy')]
deploy *ARGS:
    @# Ensure host keys and secrets exist (idempotent)
    nix run .#scaffold -- $(echo {{ ARGS }} | awk '{print $1}')
    nix run .#deploy -- {{ ARGS }}

# Update all flake inputs or specific inputs (e.g., just up INPUT1 INPUT2)
[group('maintenance')]
up *ARGS:
    nix flake update {{ ARGS }}

# Show the system profile history
[group('maintenance')]
history:
    nix profile history --profile /nix/var/nix/profiles/system

# Remove all system generations older than {{ DAYS }}
[group('maintenance')]
clean DAYS='7':
    sudo nix profile wipe-history --profile /nix/var/nix/profiles/system --older-than {{ DAYS }}d
    just garbage-collect

# Garbage collect all unused Nix store entries
[group('maintenance')]
garbage-collect HOST='$(hostname)':
    ssh {{ HOST }} sudo nix-collect-garbage --delete-old

alias gc := garbage-collect

# Open the Nix REPL with the nixpkgs flake
[group('development')]
repl:
    nix repl -f flake:nixpkgs

# Scaffold a new system and home configuration
[group('development')]
scaffold *ARGS:
    nix run .#scaffold -- {{ ARGS }}

# Format all Nix files in the repository
[group('development')]
format:
    nix fmt .

# Interactively encrypt a new secret
[group('secrets')]
encrypt:
    nix run .#secrets -- encrypt

# Re-encrypt all secrets for all hosts
[group('secrets')]
rekey:
    #!/usr/bin/env bash
    set -euo pipefail
    # Collect all available host identity files
    ids=(-i "$HOME/.ssh/id_rsa" -i "$HOME/.ssh/id_ed25519")
    for k in /etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_rsa_key; do
      [ -r "$k" ] && ids+=(-i "$k")
    done
    RULES=secrets/default.nix nix run github:ryantm/agenix -- -r "${ids[@]}"

# Generate syncthing identity for a host
[group('syncthing')]
syncthing-keygen HOSTNAME:
    nix run .#syncthing-keygen -- {{ HOSTNAME }}
