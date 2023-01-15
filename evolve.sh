#! /usr/bin/env nix-shell
#! nix-shell -i bash

set -e

./update.sh \
  && ./apply.sh
