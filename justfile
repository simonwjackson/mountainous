############################################################################
#
#  Nix commands related to the local machine
#
############################################################################

# Default recipe
default:
    @just --list

deploy *ARGS:
    #!/usr/bin/env bash
    if [ "$(uname)" == "Darwin" ]; then \
        echo "MacOS is unsupported at this time."
    else \
        ./scripts/deploy.sh
    fi

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

build *ARGS:
    #!/usr/bin/env bash
    if [ "$(uname)" == "Darwin" ]; then \
        sudo nix run nix-darwin -- build --flake ".#$(hostname)" {{ ARGS }}; \
    else \
        nixos-rebuild build --flake ".#$(hostname)" --target-host "$(hostname)" --use-remote-sudo --use-substitutes {{ ARGS }};
    fi

dry *ARGS:
    #!/usr/bin/env bash
    if [ "$(uname)" == "Darwin" ]; then \
        nix build ".#darwinConfigurations.$(hostname).config.system.build.toplevel" {{ ARGS }}; \
    else \
        nix build ".#nixosConfigurations.$(hostname).config.system.build.toplevel" {{ ARGS }}; \
    fi

debug *ARGS:
    just switch --show-trace --verbose {{ ARGS }}

evolve *ARGS:
    just up
    just switch {{ ARGS }}

evolve-all *ARGS:
    #!/usr/bin/env bash
    just up && \
    sh -c './scripts/deploy.sh'

up:
    nix flake update

# Update specific input

# usage: make up-this home-manager
up-this *ARGS:
    nix flake lock --update-input {{ ARGS }}

history:
    nix profile history --profile /nix/var/nix/profiles/system

repl:
    nix repl -f flake:nixpkgs

clean:
    # remove all generations older than 7 days
    sudo nix profile wipe-history --profile /nix/var/nix/profiles/system  --older-than 7d

gc:
    # garbage collect all unused nix store entries
    sudo nix-collect-garbage --delete-old
