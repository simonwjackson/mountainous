############################################################################
#
#  Nix commands related to the local machine
#
############################################################################

# Default recipe
default:
    @just --list --unsorted

# TODO: Rethink this script. There is quite a bit of overlap between this
# and `switch`. How can they work together?
# # Deploy the system configuration
# deploy *ARGS:
#     #!/usr/bin/env bash
#     if [ "$(uname)" == "Darwin" ]; then \
#         echo "MacOS is unsupported at this time."
#     else \
#         ./scripts/deploy.sh
#     fi

# Switch to the system configuration for the specified hostname, optionally providing comma-separated build hosts (defaults to the hostname if not provided)
switch HOST='$(hostname)' BUILD_HOSTS='':
    nix run .#switcher switch {{ HOST }} {{ BUILD_HOSTS }}

# Build the system configuration for the specified hostname
build HOST='$(hostname)' BUILD_HOSTS='':
    nix run .#switcher build {{ HOST }} {{ BUILD_HOSTS }}

# Perform a dry run of the system configuration for the specified hostname
dry-run HOST='$(hostname)':
    #!/usr/bin/env bash

    HOSTNAME="{{ HOST }}"; \

    if [ "$(uname)" == "Darwin" ]; then
        nix build ".#darwinConfigurations.$HOSTNAME.config.system.build.toplevel"; \
    else \
        nix build ".#nixosConfigurations.$HOSTNAME.config.system.build.toplevel"; \
    fi

alias dry := dry-run

# FIX: `just switch` also accepts a host name
# Debug the system configuration with additional arguments
# debug *ARGS:
#     just switch --show-trace --verbose {{ ARGS }}

# Update the flake and switch to the new configuration
evolve *ARGS:
    just up
    just switch {{ ARGS }}

# Update all flake inputs or specific inputs (e.g., just up INPUT1 INPUT2)
up *ARGS:
    nix flake update {{ ARGS }}

# Show the system profile history
history:
    nix profile history --profile /nix/var/nix/profiles/system

# Open the Nix REPL with the nixpkgs flake
repl:
    nix repl -f flake:nixpkgs

# Remove all system generations older than {{ DAYS }}
clean DAYS='7':
    sudo nix profile wipe-history --profile /nix/var/nix/profiles/system --older-than {{ DAYS }}d

# Garbage collect all unused Nix store entries
garbage-collect HOST='$(hostname)':
    ssh {{ HOST }} sudo nix-collect-garbage --delete-old

alias gc := garbage-collect
