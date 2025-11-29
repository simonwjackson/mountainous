#!/usr/bin/env bash

# Example extraction utility

function print_usage() {
  echo "Usage: ex <file>"
  echo "Extracts various compressed file formats"
  echo ""
  echo "Supported formats: tar, tar.gz, tar.bz2, tar.xz, zip, rar, 7z, gz, bz2, Z"
}

if [ -z "$1" ]; then
  print_usage
  exit 1
fi

if [ ! -f "$1" ]; then
  echo "Error: File '$1' not found."
  exit 1
fi

case "$1" in
  *.tar.bz2 | *.tbz2) tar xjf "$1" ;;
  *.tar.gz | *.tgz) tar xzf "$1" ;;
  *.tar.xz | *.txz) tar xJf "$1" ;;
  *.tar) tar xf "$1" ;;
  *.bz2) bunzip2 "$1" ;;
  *.gz) gunzip "$1" ;;
  *.zip) unzip "$1" ;;
  *.7z) 7z x "$1" ;;
  *)
    echo "Error: Unsupported file format for '$1'"
    print_usage
    exit 1
    ;;
esac

echo "Extracted $1 successfully."
