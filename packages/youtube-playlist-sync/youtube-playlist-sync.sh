#!/usr/bin/env bash

###########################################
# Constants and Global Variables
###########################################

trap 'echo "Script interrupted. Exiting..."; exit 1' SIGINT

PLAYLISTS=()
DIRECTORY="$HOME/Music"
VERBOSE=false
MOVE_MISSING=""
DRY_RUN=false
PROCESSED_FILES=()
EXISTING_FILES=()
declare -A PLAYLIST_METADATA

###########################################
# Utility Functions
###########################################

print_usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --playlist PLAYLIST_ID  YouTube playlist ID to process (can be used multiple times)
  --directory DIR         Root directory where final downloads are placed (default: $HOME/Music)
  --verbose               Enable verbose output
  --move-missing PATH     Move MP3 files in the output directory that weren't processed to the specified path
  --dry-run               Simulate the process without making any changes
  --help                  Display this help message and exit

You can also pipe in JSONL data for playlist objects:
  cat "./my.jsonl" | $0 [OPTIONS]

JSONL format example:
{"album":"Album Name","artist":"Artist Name","date":"YYYY-MM-DD","id":"PLAYLIST_ID"}

EOF
}

log() {
  local level="$1"
  shift
  local message="$1"
  shift

  gum log --level "$level" "$message" "$@"
}

sanitize_string() {
  echo "$1" | tr -d '[:cntrl:]' | tr -s '/' '-' | tr -s ':' '-' | sed 's/[^a-zA-Z0-9 _-]//g' | sed 's/^ *//g' | sed 's/ *$//g'
}

###########################################
# Input Processing Functions
###########################################

process_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
    --playlist)
      PLAYLISTS+=("$2")
      shift 2
      ;;
    --directory)
      DIRECTORY="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --move-missing)
      MOVE_MISSING="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help)
      print_usage
      exit 0
      ;;
    *)
      log error "Error: Unknown option: $1" >&2
      print_usage
      exit 1
      ;;
    esac
  done
}

process_jsonl_input() {
  while IFS= read -r line; do
    if [[ -n "$line" ]]; then
      album=$(echo "$line" | jq -r '.album // empty')
      artist=$(echo "$line" | jq -r '.artist // empty')
      date=$(echo "$line" | jq -r '.date // empty')
      id=$(echo "$line" | jq -r '.id // empty')

      if [[ -n "$id" ]]; then
        log info "Processing playlist from JSONL: $id"
        PLAYLISTS+=("$id")

        if [[ -n "$album" && -n "$artist" && -n "$date" ]]; then
          # Store metadata for later use
          PLAYLIST_METADATA["$id"]=$(jq -n \
            --arg album "$album" \
            --arg artist "$artist" \
            --arg date "$date" \
            '{album: $album, artist: $artist, date: $date}')
        fi
      else
        log error "Invalid JSONL input: missing 'id' field"
      fi
    fi
  done
}

###########################################
# File and Directory Operations
###########################################

scan_directory() {
  local dir="$1"
  log info "Scanning directory for existing MP3 files: $dir"

  while IFS= read -r -d '' file; do
    local relative_path="${file#"$dir"/}"
    EXISTING_FILES+=("$relative_path")
  done < <(find "$dir" -type f -name "*.mp3" -print0)

  log info "Found ${#EXISTING_FILES[@]} existing MP3 files"
}

file_exists() {
  local metadata="$1"
  local sanitized_album sanitized_artist sanitized_title

  sanitized_album=$(sanitize_string "$(echo "$metadata" | jq -r '.album')")
  sanitized_artist=$(sanitize_string "$(echo "$metadata" | jq -r '.artist')")
  sanitized_title=$(sanitize_string "$(echo "$metadata" | jq -r '.title')")

  for existing_file in "${EXISTING_FILES[@]}"; do
    if [[ "$existing_file" == *"$sanitized_artist"* && "$existing_file" == *"$sanitized_album"* && "$existing_file" == *"$sanitized_title"* ]]; then
      log info "File already exists: $existing_file"
      return 0
    fi
  done

  return 1
}

move_missing_files() {
  log info "Moving missing MP3 files..."

  if [ ! -d "$MOVE_MISSING" ]; then
    if [[ $DRY_RUN == true ]]; then
      log debug "[DRY RUN] Would create directory: $MOVE_MISSING"
    else
      mkdir -p "$MOVE_MISSING"
    fi
  fi
  find "$DIRECTORY" -type f -name "*.mp3" | while read -r file; do
    if ! printf '%s\0' "${PROCESSED_FILES[@]}" | grep -F -x -z -- "$file" >/dev/null; then
      if [[ $DRY_RUN == true ]]; then
        log debug "[DRY RUN] Would move: $file to $MOVE_MISSING"
      else
        log info "Moving: $file to $MOVE_MISSING"
        mv "$file" "$MOVE_MISSING"
      fi
    fi
  done
}

###########################################
# YouTube and Download Operations
###########################################

get_youtube_metadata() {
  local youtube_id="$1"
  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/yt-dlp"
  local cache_file="${cache_dir}/${youtube_id}.json"

  # Create cache directory if it doesn't exist
  mkdir -p "$cache_dir"

  # Function to process JSON with jq
  process_json() {
    jq '{
      id: .id,
      artist: .artist,
      album: .album,
      title: .title,
      upload_date: (.upload_date | strptime("%Y%m%d") | strftime("%Y-%m-%d")),
      thumbnail_url: (
        .thumbnails |
        map(select(.width == .height)) |
        sort_by(.width) |
        last |
        .url
      )
    }'
  }

  # Check if cached file exists and is not empty
  if [[ -s "$cache_file" ]]; then
    cat "$cache_file" | process_json
  else
    # If not cached, fetch and cache the data
    yt-dlp \
      --dump-single-json \
      "https://www.youtube.com/watch?v=${youtube_id}" |
      tee "$cache_file" |
      process_json
  fi
}

download_and_convert() {
  local id="$1"
  local full_output_path="$2"

  if [[ $DRY_RUN == true ]]; then
    log debug "[DRY RUN] Would download and convert: $id to $full_output_path"
  else
    yt-dlp -f 'bestaudio' -o - "$id" |
      ffmpeg -i pipe:0 -vn -acodec libmp3lame -q:a 2 "$full_output_path"
  fi
}

###########################################
# Audio Processing and Tagging Functions
###########################################

import_to_beets() {
  local mp3_file="$1"
  local config_file
  local db_file
  local expect_script

  config_file=$(mktemp)
  db_file=$(mktemp)
  expect_script=$(mktemp)

  # Create temporary beets config
  cat <<EOF >"$config_file"
import:
    write: yes
    copy: no
    move: no
    bell: no
match:
    preferred:
        countries: []
        media: []
        original_year: no
    distance_weights:
        album: 2.0
        artist: 3.0
        track: 3.0
        track_index: 1.0
        track_length: 2.0
        year: 1.0
EOF

  escaped_mp3_file=$(printf '%q' "$mp3_file")

  cat <<EOF >"$expect_script"
#!/usr/bin/expect -f
set timeout 30
spawn beet -l "$db_file" -c "$config_file" import $escaped_mp3_file
expect {
    "  Candidates:" { send "1\r"; exp_continue }
    "candidates" { send "a\r"; exp_continue }
    "No matching" { send "\r"; exp_continue }
    timeout { puts "Operation timed out"; exit 1 }
    eof
}
EOF

  chmod +x "$expect_script"

  if [[ $VERBOSE == true ]]; then
    expect "$expect_script"
  else
    expect "$expect_script" >/dev/null 2>&1
  fi

  rm "$config_file" "$expect_script" "$db_file"
}

tag_and_process() {
  local full_output_path="$1"
  local title="$2"
  local artist="$3"
  local album="$4"
  local date="$5"
  local thumbnail_url="$6"

  if [[ $DRY_RUN == true ]]; then
    log debug "[DRY RUN] Would tag and process: $full_output_path"
    return 0
  fi

  thumbnail_file=$(mktemp --suffix=.jpg)

  # Download the thumbnail
  if ! curl -s -o "$thumbnail_file" "$thumbnail_url"; then
    log error "Failed to download thumbnail from $thumbnail_url"
    rm -f "$thumbnail_file"
    return 1
  fi

  fingerprint=$(fpcalc -json "$full_output_path" | jq -r '.fingerprint // empty')

  tone tag "$full_output_path" \
    --meta-title "$title" \
    --meta-artist "$artist" \
    --meta-album "$album" \
    --meta-publishing-date "$date" \
    --meta-cover-file "$thumbnail_file" \
    --meta-additional-field "acoustid Fingerprint=${fingerprint}"

  import_to_beets "$full_output_path"

  rm -f "$thumbnail_file"
}

###########################################
# Playlist Processing Functions
###########################################

process_audio() {
  local metadata="$1"

  trap 'log error "Processing interrupted. Exiting..."; exit 1' SIGINT

  id=$(echo "$metadata" | jq -r '.id')
  title=$(echo "$metadata" | jq -r '.title')
  artist=$(echo "$metadata" | jq -r '.artist')
  album=$(echo "$metadata" | jq -r '.album')
  date=$(echo "$metadata" | jq -r '.upload_date')
  year=${date%%-*} # Extract year from the date
  thumbnail_url=$(echo "$metadata" | jq -r '.thumbnail_url')

  sanitized_album=$(sanitize_string "$album")
  sanitized_artist=$(sanitize_string "$artist")
  sanitized_title=$(sanitize_string "$title")

  output_dir="$DIRECTORY/${sanitized_album:+${sanitized_album} [${year}] - }${sanitized_artist}"
  output_file="${sanitized_title}.mp3"
  full_output_path="${output_dir}/${output_file}"

  if file_exists "$metadata"; then
    PROCESSED_FILES+=("$full_output_path")
    log info "Skipping download for existing file: $title by $artist"
    return 0
  fi

  if [[ $DRY_RUN == true ]]; then
    log debug "[DRY RUN] Would create directory: $output_dir"
  else
    mkdir -p "$output_dir"
  fi

  if download_and_convert "$id" "$full_output_path"; then
    log info "Audio downloaded and converted successfully."

    if tag_and_process "$full_output_path" "$title" "$artist" "$album" "$date" "$thumbnail_url"; then
      log info "Audio tagged and processed successfully: $full_output_path"
      PROCESSED_FILES+=("$full_output_path")
    else
      log error "Failed to tag and process audio for ID: $id"
      if [[ ! $DRY_RUN ]]; then
        rm -f "$full_output_path"
      fi
    fi
  else
    log info "Failed to download and convert audio for ID: $id"
  fi

  trap - SIGINT
}

process_playlist() {
  local playlist_id="$1"

  trap 'log error "Playlist processing interrupted. Exiting..."; exit 1' SIGINT
  log info "Processing playlist: $playlist_id"

  video_ids=$(yt-dlp --flat-playlist --get-id "$playlist_id")

  for video_id in $video_ids; do
    log info "Processing video: $video_id"

    metadata=$(get_youtube_metadata "$video_id")

    if [ -n "$metadata" ]; then
      process_audio "$metadata"
    else
      log error "Failed to get metadata for video: $video_id"
    fi
  done

  log info "Playlist processing complete."

  trap - SIGINT
}

process_all_playlists() {
  log info "Processing multiple playlists"

  for playlist_id in "${PLAYLISTS[@]}"; do
    log info "Starting to process playlist: $playlist_id"
    process_playlist "$playlist_id"
    log info "Finished processing playlist: $playlist_id"
  done

  log info "All playlists have been processed."
}

###########################################
# Main Execution
###########################################

# Process JSONL input if available
if [ -p /dev/stdin ]; then
  process_jsonl_input
fi

process_arguments "$@"

if [ ${#PLAYLISTS[@]} -eq 0 ]; then
  log error "At least one playlist must be specified using --playlist option or piped JSONL input." >&2
  print_usage
  exit 1
fi

if [[ $VERBOSE == true ]]; then
  set -x # Enable verbose mode
fi

if [[ $DRY_RUN == true ]]; then
  log debug "[DRY RUN] This is a dry run. No changes will be made."
fi

trap 'log error "Script interrupted. Exiting..."; exit 1' SIGINT

scan_directory "$DIRECTORY"
process_all_playlists

if [ -n "$MOVE_MISSING" ]; then
  move_missing_files
fi

trap - SIGINT

if [[ $VERBOSE == true ]]; then
  set +x # Disable verbose mode
fi

log info "Script execution completed."
