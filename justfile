############################################################################
#
#  Nix commands related to the local machine
#
############################################################################

# Default recipe
default:
    @just --list

# Deploy the system configuration
deploy *ARGS:
    #!/usr/bin/env bash
    if [ "$(uname)" == "Darwin" ]; then \
        echo "MacOS is unsupported at this time."
    else \
        ./scripts/deploy.sh
    fi

# Switch to the system configuration for the specified hostname
switch +HOSTNAME="":
    #!/usr/bin/env bash
    if [ -z "$HOSTNAME" ]; then \
        HOSTNAME=$(hostname); \
    fi; \
    if [ "$(uname)" == "Darwin" ]; then \
        sudo nix run nix-darwin \
        -- switch --flake ".#$HOSTNAME"; \
    else \
        nixos-rebuild switch \
          --flake ".#$HOSTNAME" \
          --target-host "$HOSTNAME" \
          --build-host "$HOSTNAME" \
          --use-remote-sudo \
          --use-substitutes; \
    fi

# Build the system configuration for the specified hostname
build +HOSTNAME="":
    #!/usr/bin/env bash
    if [ -z "$HOSTNAME" ]; then \
        HOSTNAME=$(hostname); \
    fi; \
    if [ "$(uname)" == "Darwin" ]; then \
        sudo nix run nix-darwin -- build --flake ".#$HOSTNAME"; \
    else \
        nixos-rebuild build --flake ".#$HOSTNAME" --target-host "$HOSTNAME" --use-remote-sudo --use-substitutes;
    fi

# Perform a dry run of the system configuration for the specified hostname
dry-run +HOSTNAME="":
    #!/usr/bin/env bash
    if [ -z "$HOSTNAME" ]; then \
        HOSTNAME=$(hostname); \
    fi; \
    if [ "$(uname)" == "Darwin" ]; then \
        nix build ".#darwinConfigurations.$HOSTNAME.config.system.build.toplevel"; \
    else \
        nix build ".#nixosConfigurations.$HOSTNAME.config.system.build.toplevel"; \
    fi

# Alias for dry-run

alias dry := dry-run

# Debug the system configuration with additional arguments
debug *ARGS:
    just switch --show-trace --verbose {{ ARGS }}

# Update the flake and switch to the new configuration
evolve *ARGS:
    just up
    just switch {{ ARGS }}

# Update the flake and deploy the new configuration to all systems
evolve-all *ARGS:
    #!/usr/bin/env bash
    just up && \
    sh -c './scripts/deploy.sh'

# Update all flake inputs or specific inputs (e.g., just up INPUT1 INPUT2)
up *ARGS:
    nix flake update {{ ARGS }}

# Show the system profile history
history:
    nix profile history --profile /nix/var/nix/profiles/system

# Open the Nix REPL with the nixpkgs flake
repl:
    nix repl -f flake:nixpkgs

# Remove all system generations older than 7 days
clean:
    sudo nix profile wipe-history --profile /nix/var/nix/profiles/system  --older-than 7d

# Garbage collect all unused Nix store entries
gc:
    sudo nix-collect-garbage --delete-old
