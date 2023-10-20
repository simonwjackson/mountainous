build *ARGS:
  nixos-rebuild --flake .# build $@

deploy *ARGS:
  ./deploy.sh {{ARGS}}

home *ARGS:
  home-manager  -b backup --flake ".#$(whoami)@$(hostname)"

update *ARGS:
  nix flake update

evolve:
  just update
  just deploy