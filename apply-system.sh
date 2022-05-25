#!/bin/sh

set -e

# if [ -n "$(git status --porcelain)" ]; then
#   echo "Commit your changes"
#   exit 1
# else
  sudo nixos-rebuild \
    -v switch \
    --flake '.#'
# fi
# --profile-name "$(git log -1 --pretty=%B | sed "s/[^[:alnum:]-]/-/g")" \
