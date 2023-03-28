#! /usr/bin/env nix-shell
#! nix-shell -i bash -p _1password

ifnotset () {
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

lineinfile () {
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
# mkdir -p "${HOME}/.config/rofi"
# touch "${HOME}/.config/rofi/config.rasi"
# lineinfile '@import "config.base.rasi' '@import "config.base.rasi"' "${HOME}/.config/rofi/config.rasi"
# ifnotset   '^@theme\s*' '@theme "themes/dracula/config1.rasi"' "${HOME}/.config/rofi/config.rasi"
# lineinfile '@import "overrides.rasi' '@import "overrides.rasi"' "${HOME}/.config/rofi/config.rasi"

# if file not exist, curl it into the file
# Usage: curlifnotexist URL FILE
curlifnotexist () {
  if [[ $# != 2 ]];then
    local THIS_FUNC_NAME="${funcstack[1]-}${FUNCNAME[0]-}"
    echo "$THIS_FUNC_NAME - 2 arguments are expected. given $#. args=[$@]" >&2
    echo "usage: $THIS_FUNC_NAME URL FILE" >&2
    return 1
  fi

  local URL="$1"
  local FILE="$2"

  if [[ ! -f "${FILE}" ]]; then
    mkdir -p "$(dirname "${FILE}")"
    curl -s "${URL}" > "${FILE}"
  fi
}

curlifnotexist "https://raw.githubusercontent.com/dracula/rofi/master/theme/config1.rasi" "${HOME}/.config/rofi/themes/dracula/config1.rasi"

# Kitty
mkdir -p "${HOME}/.config/kitty"
touch "${HOME}/.config/kitty/kitty.conf"
lineinfile 'include kitty.base.conf' 'include kitty.base.conf' "${HOME}/.config/kitty/kitty.conf"
