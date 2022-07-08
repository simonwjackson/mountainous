#!/bin/sh

function ifnotset () {
  if [[ $# != 3 ]];then
    local THIS_FUNC_NAME="${funcstack[1]-}${FUNCNAME[0]-}"
    echo "$THIS_FUNC_NAME - 3 arguments are expected. given $#. args=[$@]" >&2
    echo "usage: $THIS_FUNC_NAME PATTERN LINE FILE" >&2
    return 1
  fi

  local PATTERN="$1"
  local LINE="$2"
  local FILE="$3"

  if grep -E -q "${PATTERN}" "${FILE}"; then
     echo '' 
  else
    echo "$LINE" >> "$FILE";
  fi
}

function lineinfile () {
  if [[ $# != 3 ]];then
    local THIS_FUNC_NAME="${funcstack[1]-}${FUNCNAME[0]-}"
    echo "$THIS_FUNC_NAME - 3 arguments are expected. given $#. args=[$@]" >&2
    echo "usage: $THIS_FUNC_NAME PATTERN LINE FILE" >&2
    return 1
  fi

  local PATTERN="$1"
  local LINE="$2"
  local FILE="$3"

  if grep -E -q "${PATTERN}" "${FILE}" ;then
    PATTERN="${PATTERN}" LINE="${LINE}" perl -i -nle 'if(/$ENV{"PATTERN"}/){print $ENV{"LINE"}}else{print}' "${FILE}"
  else
    echo "$LINE" >> "$FILE"
  fi
}

# Rofi
mkdir -p ${HOME}/.config/rofi
touch ${HOME}/.config/rofi/config.rasi
lineinfile '@import "config.base.rasi' '@import "config.base.rasi"' ${HOME}/.config/rofi/config.rasi
ifnotset   '^@theme\s*' '@theme "themes/dracula/config1.rasi"' ${HOME}/.config/rofi/config.rasi

# Kitty
mkdir -p ${HOME}/.config/kitty
touch ${HOME}/.config/kitty/kitty.conf
lineinfile 'include kitty.base.conf' 'include kitty.base.conf' ${HOME}/.config/kitty/kitty.conf
