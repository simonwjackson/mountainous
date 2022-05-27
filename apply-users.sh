#!/bin/sh

set -e

op run --env-file=.env -- nix build .#homeConfigurations.$(whoami).activationPackage \
&& ./result/activate \
&& op run --env-file=.env -- ./apply-users.post.sh
