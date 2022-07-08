#!/bin/sh

set -e

# if [ -n "$(git status --porcelain)" ]; then
#   echo "Commit your changes"
#   exit 1
# else

# if ! op account get; then
#   eval $(op signin)
# fi
# if op account get; then
  op run --env-file=.env -- sudo -E nixos-rebuild --impure -v switch --flake .#
# fi
# fi
    # --impure \
# --profile-name "$(git log -1 --pretty=%B | sed "s/[^[:alnum:]-]/-/g")" \
