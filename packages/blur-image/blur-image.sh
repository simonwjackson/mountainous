#!/usr/bin/env bash

set -euo pipefail

# Function to print usage
print_usage() {
  echo "Usage: $0 [options] input output"
  echo "Options:"
  echo "  -a, --amount <amount>    Set blur amount (default: 100)"
  echo "  -h, --help              Display this help message"
  echo ""
  echo "Arguments:"
  echo "  input                    Path to input image"
  echo "  output                   Path to output image"
}

function main() {
  # Parse command line arguments
  if ! TEMP=$(getopt -o 'a:h' --long 'amount:,help' -n "$0" -- "$@"); then
    echo "Try '$0 --help' for more information."
    exit 1
  fi

  # Note the quotes around "$TEMP": they are essential!
  eval set -- "$TEMP"
  unset TEMP

  # Set default blur amount
  local BLUR_AMOUNT=100

  while true; do
    case "$1" in
    '-a' | '--amount')
      BLUR_AMOUNT="$2"
      shift 2
      continue
      ;;
    '-h' | '--help')
      print_usage
      exit 0
      ;;
    '--')
      shift
      break
      ;;
    *)
      echo "Internal error!" >&2
      exit 1
      ;;
    esac
  done

  # Check for required positional arguments
  if [ $# -ne 2 ]; then
    echo "Error: Both input and output paths are required" >&2
    print_usage
    exit 1
  fi

  local INPUT_IMAGE="$1"
  local OUTPUT_IMAGE="$2"
  local OUTPUT_DIR
  OUTPUT_DIR="$(dirname "$OUTPUT_IMAGE")"

  # Print current settings
  echo "Using settings:"
  echo "Blur amount: $BLUR_AMOUNT"
  echo "Input image: $INPUT_IMAGE"
  echo "Output image: $OUTPUT_IMAGE"

  # Ensure input image exists
  if [ ! -f "$INPUT_IMAGE" ]; then
    echo "Error: Input image does not exist at $INPUT_IMAGE" >&2
    exit 1
  fi

  mkdir -p "$OUTPUT_DIR"
  convert "$INPUT_IMAGE" -blur 0x"$BLUR_AMOUNT" "$OUTPUT_IMAGE"
}

main "$@"
