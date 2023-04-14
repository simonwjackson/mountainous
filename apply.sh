#! /usr/bin/env nix-shell
#! nix-shell -i bash -p _1password

set -e

source _pre.sh

./apply-system.sh 
#&& ./apply-users.sh
