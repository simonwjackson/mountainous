#!/bin/sh

set -e

if ! op account get; then
  eval $(op signin)
fi
if op account get; then
  ./apply-system.sh && ./apply-users.sh
fi
