#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash systemd
# This is the only root operation granted to the application deploy account.
set -euo pipefail
if [[ $# -ne 1 ]]; then
  echo 'Expected one service-control action' >&2
  exit 2
fi
case "$1" in
  prepare)
    systemctl stop cliproxyapi-quota-router.timer cliproxyapi-tsnet.service cliproxyapi-quota-router.service
    ;;
  quiesce)
    systemctl stop cliproxyapi.service
    ;;
  core)
    systemctl start cliproxyapi.service
    ;;
  network)
    systemctl start cliproxyapi-tsnet.service
    systemctl start cliproxyapi-quota-router.service
    ;;
  timer)
    systemctl start cliproxyapi-quota-router.timer
    ;;
  stop)
    systemctl stop cliproxyapi-quota-router.timer cliproxyapi-tsnet.service cliproxyapi-quota-router.service cliproxyapi.service
    ;;
  *)
    echo 'Unsupported service-control action' >&2
    exit 2
    ;;
esac
