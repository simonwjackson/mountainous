#!/bin/sh

set -e

if ! op account get; then
  eval $(op signin)
fi
if op account get; then
  op run --env-file=.env -- ./apply-users.pre.sh \
  && op run --env-file=.env -- nix build --impure .#homeConfigurations.$(whoami).activationPackage \
  && ./result/activate \
  && op run --env-file=.env -- ./apply-users.post.sh
fi
