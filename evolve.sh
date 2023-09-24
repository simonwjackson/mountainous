#! /usr/bin/env nix-shell
#! nix-shell -i bash -p bash _1password

set -e

[[ $(op account get) ]] || eval "$(op signin)"

./update.sh &&
  nix flake update \
    --extra-experimental-features nix-command \
    --extra-experimental-features flakes &&
  op run \
    --env-file="./hosts/$(hostname)/system.env" --env-file=.env \
    -- sudo -E nixos-rebuild --impure -v switch --flake '.#' &&
  op run \
    --env-file=.env \
    -- ./post.sh
