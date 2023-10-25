#!/usr/bin/env bash

# TODO: use a schema to validate json
# TODO: load functions as plugins from a directory

set -euo pipefail

cleanup() {
  rm "${all}" "${project_selection}"
}

# Define the command to run on each server
list_all_code_projects() {
  ssh $1 "nix \
      --extra-experimental-features flakes \
      --extra-experimental-features nix-command \
      run 'nixpkgs#fd' -- --type directory --hidden '^.bare$|^.git$' --search-path ~/code" |
    xargs -I @ echo -e "@\t" '{"server":"'$server'","path":"@","label":"@","id":"@","cmd":"nvim @"}' |
    awk 'BEGIN { FS=OFS="\t" } { cmd="echo "$1" | md5sum | cut -d \" \" -f1"; cmd | getline result; close(cmd); $1=result; print $0; }'
}

list_some_apps() {
  apps=("btop" "nvim")
  servers=$1
  for app in "${apps[@]}"; do
    echo -e $app '\t{"server":"'$server'","type":"app","cmd":"nix run nixpkgs#'$app'","label":"'$app'","id":"'$app'"}'
  done &
}

servers=("localhost")

local_only=0

if [ $local_only -eq 0 ]; then
  servers=("unzen" "fiji" "zao")
fi

all=$(mktemp)
project_selection=$(mktemp)

for server in "${servers[@]}"; do
  list_all_code_projects $server |
    tee --append "${all}" &

  list_some_apps $server |
    tee --append "${all}" &
done |
  stdbuf \
    --output L \
    awk -F '\t' '!seen[$1]++ { $1=""; print $0 }' |
  jq \
    --compact-output \
    --raw-output \
    --unbuffered '"\(.)\t\(.label)"' |
  fzf \
    --delimiter '\t' \
    --with-nth=2 |
  awk -F "\t" '{print $1}' \
    >"${project_selection}"

if [ $? -eq 0 ]; then
  cat "${all}" |
    awk '{$1=""; print $0}' |
    sort -u |
    jq \
      --raw-output \
      --compact-output \
      'select(.id=="'$(cat "${project_selection}" | jq --raw-output '.id')'") | tostring + "\t" +.server ' |
    fzf \
      --delimiter '\t' \
      --with-nth=2 \
      --select-1 |
    awk -F "\t" '{print $1}' |
    jq -cr '. | "tmux new-session -d -s \(.label) -- mosh \(.server) -- \(.cmd)"' |
    sh
fi

if [ $? -eq 0 ]; then
  jq '. | "tmux switch-clent -t \(.label)"' "${project_selection}" | xargs
fi

trap cleanup EXIT
