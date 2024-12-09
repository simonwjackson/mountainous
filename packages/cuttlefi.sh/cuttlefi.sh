#!/usr/bin/env bash

# INFO: for debug purposes only
#!/usr/bin/env -S nix shell nixpkgs#bash nixpkgs#yq nixpkgs#yt-dlp nixpkgs#gum -c bash

# Podcast downloader script that downloads episodes from subscription list
doc="Podcast Downloader

Downloads podcasts from a YAML subscription file with sponsorblock filtering.

Usage:
  $(basename "$0") --config <config.yaml>
  $(basename "$0") -h | --help

Options:
  -c, --config <path>  Path to subscription YAML file
  -h, --help          Show this screen.
"

CONFIG_FILE=""

log() {
  local level="$1"
  shift
  local message="$1"
  shift

  # Execute the log command
  if [[ "$level" == "fatal" ]]; then
    gum log --level "$level" "FATAL: $message"
    exit 1
  else
    gum log --level "$level" "$message"
  fi
}

process_config() {
  local config="$1"

  if [[ ! -f "$config" ]]; then
    log fatal "Config file not found" path "$config"
  fi

  # Extract download directory and archive file from config
  local download_dir
  download_dir=$(yq -r '.download_dir' "$config")

  local archive_file
  archive_file=$(yq -r '.archive_file' "$config")

  if [[ -z "$download_dir" ]]; then
    log fatal "download_dir not specified in config"
  fi

  if [[ -z "$archive_file" ]]; then
    log fatal "archive_file not specified in config"
  fi

  # Create download directory if it doesn't exist
  if [[ ! -d "$download_dir" ]]; then
    log info "Creating download directory" path "$download_dir"
    mkdir -p "$download_dir"
  fi

  # Create archive file directory if it doesn't exist
  local archive_dir
  archive_dir=$(dirname "$archive_file")
  if [[ ! -d "$archive_dir" ]]; then
    log info "Creating archive directory" path "$archive_dir"
    mkdir -p "$archive_dir"
  fi

  # Use yq to generate download commands
  while IFS= read -r cmd; do
    log info "Executing download command" cmd "$cmd"
    if ! eval "$cmd"; then
      log error "Failed to execute command" cmd "$cmd"
    fi
  done < <(yq -r '
    .max_episodes as $global_max_episodes |
    .download_dir as $base_dir |
    .archive_file as $archive |
    .subscriptions[] |
    "yt-dlp -x --audio-format mp3 --download-archive \"\($archive)\" --sponsorblock-remove sponsor,selfpromo,interaction,intro,outro --playlist-reverse \(
      if (.max_episodes // $global_max_episodes) == -1 then
        ""
      else
        "--playlist-end \(.max_episodes // $global_max_episodes)"
      end
    ) -o \"\($base_dir)/\(.name)/%(title)s.%(ext)s\" \(.url)"
  ' "$config")
}

main() {
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
    -c | --config)
      CONFIG_FILE="$2"
      shift 2
      ;;
    -h | --help)
      echo "$doc"
      exit 0
      ;;
    *)
      log error "Unknown option: $1"
      echo "$doc"
      exit 1
      ;;
    esac
  done

  if [[ -z "$CONFIG_FILE" ]]; then
    log fatal "No config file specified"
  fi

  process_config "$CONFIG_FILE"
}

# Only run the main function if the script is being executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
