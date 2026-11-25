#!/usr/bin/env bash
set -euo pipefail
exec ssh -F /dev/null -o 'ProxyCommand=ssh -F /dev/null -W 127.0.0.1:2223 simon@myoko' \
  -o HostKeyAlias=asama-vm-on-myoko -o StrictHostKeyChecking=accept-new simon@asama-vm "$@"
