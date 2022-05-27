#!/bin/sh

set -e

# if [ -n "$(git status --porcelain)" ]; then
#   echo "Commit your changes"
#   exit 1
# else
op run --env-file=.env -- sudo -E nixos-rebuild --impure -v switch --flake .#
# fi
    # --impure \
# --profile-name "$(git log -1 --pretty=%B | sed "s/[^[:alnum:]-]/-/g")" \
