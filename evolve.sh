#! /usr/bin/env nix-shell
#! nix-shell -i bash -p bash

set -e

./update.sh \
  && ./apply.sh
