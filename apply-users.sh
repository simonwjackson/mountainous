#!/bin/sh

set -e

nix build .#homeConfigurations.$(whoami).activationPackage \
&& ./result/activate \
&& sudo -E su -c 'op run --env-file=.env -- ./apply-users.post.sh' $(whoami)
