#!/bin/sh

set -e

# if [ -n "$(git status --porcelain)" ]; then
#   echo "Commit your changes"
#   exit 1
# else
sudo -E su -c 'op run --env-file=.env -- sudo -E nixos-rebuild -v switch --flake .#' $(whoami)
# fi
    # --impure \
# --profile-name "$(git log -1 --pretty=%B | sed "s/[^[:alnum:]-]/-/g")" \
