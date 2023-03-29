#! /usr/bin/env nix-shell
#! nix-shell -i bash -p _1password

set -e
source _pre.sh

op run \
  --env-file=.env \
  -- ./apply-users.pre.sh \
  && op run \
  --env-file=.env \
  -- nix \
  --extra-experimental-features flakes \
  --extra-experimental-features nix-command \
  build \
  --impure ".#homeConfigurations.$(whoami).activationPackage" \
  && ./result/activate \
  && op run \
  --env-file=.env \
  -- ./apply-users.post.sh
