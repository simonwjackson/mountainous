set -euo pipefail

if [ "$2" = "up" ] || [ "$2" = "connectivity-change" ]; then
  # Check if the connection is metered
  if nmcli -t -f GENERAL.METERED connection show "$1" | grep -q yes; then
    echo "Connected to a metered network. Pausing Syncthing shares."
    syncthing-toggle pause "${MANAGED_SHARES[@]}"
  else
    echo "Connected to a non-metered network. Unpausing Syncthing shares."
    syncthing-toggle unpause "${MANAGED_SHARES[@]}"
  fi
fi
