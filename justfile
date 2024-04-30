############################################################################
#
#  Nix commands related to the local machine
#
############################################################################

deploy:
    #!/usr/bin/env bash
    if [ "$(uname)" == "Darwin" ]; then \
        sudo nix run nix-darwin -- switch --flake .; \
    else \
        nixos-rebuild switch --flake . --use-remote-sudo; \
    fi

dry:
    #!/usr/bin/env bash
    if [ "$(uname)" == "Darwin" ]; then \
        nix build .#darwinConfigurations.$(hostname).config.system.build.toplevel; \
    else \
        nix build .#nixosConfigurations.$(hostname).config.system.build.toplevel; \
    fi

debug:
    nixos-rebuild switch --flake . --use-remote-sudo --show-trace --verbose

up:
    nix flake update

# Update specific input

# usage: make upp i=home-manager
up-this:
    nix flake lock --update-input $(i)

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
