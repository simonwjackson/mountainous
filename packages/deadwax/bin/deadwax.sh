#!/usr/bin/env bash

set -euo pipefail

export DEADWAX_BASE_DIR

DEADWAX_BASE_DIR=${DEADWAX_BASE_DIR:-$(
  dirname "$(
    readlink -f "${BASH_SOURCE[0]}"
  )"
)}

source "${DEADWAX_BASE_DIR}/../lib/core.sh"

main() {
  local -r TUI_PATH="${DEADWAX_BASE_DIR}/../lib/tui.sh"
  local -r CLI_PATH="${DEADWAX_BASE_DIR}/../lib/cli.sh"
  local -r VALID_TYPES="^(album|artist|playlist|song|all)$"

  # Command handlers
  declare -A commands
  commands=(
    [tui]="exec ${TUI_PATH}"
    [cli]="exec ${CLI_PATH}"
  )

  local cmd
  if [[ $# -eq 0 ]]; then
    cmd="tui"
  elif [[ "$1" == "search" ]]; then
    shift
    if [[ $# -eq 0 ]] || [[ $# -eq 1 && "$1" =~ ${VALID_TYPES} ]]; then
      cmd="tui"
    elif [[ $# -ge 2 && "$1" =~ ${VALID_TYPES} ]]; then
      cmd="cli"
      set -- search "$@" # Preserve search command
    else
      log fatal "Invalid search syntax."
      return 1
    fi
  else
    cmd="cli"
  fi

  ${commands[$cmd]} "$@"
}

main "$@"
