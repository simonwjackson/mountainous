#!/usr/bin/env bash

#########
# Utility
#########

print_usage() {
  echo "Usage: $0 [--database|-d <database_file>] <subcommand>" >&2
  echo "Global options:" >&2
  echo "  -d, --database    Specify the input YAML file (default: $XDG_DATA_HOME/deadwax/db.yaml)" >&2
  echo "" >&2
  echo "Subcommands:" >&2
  echo "  refresh    Refresh metadata for entries in the database" >&2
  echo "  add        Add a new entry to the database" >&2
  echo "             Usage: add <key> <value>" >&2
  echo "             Example: add youtube OLAK5uy_example1234" >&2
  echo "  ids        List all unique IDs for a given source" >&2
  echo "             Usage: ids <source>" >&2
  echo "             Example: ids youtube" >&2
  echo "  dump       Dump the database content" >&2
  echo "             Usage: dump [--format <format>]" >&2
  echo "             Supported formats: json (default), jsonl" >&2
}

format_date() {
  local date_string="$1"
  case ${#date_string} in
  8) echo "${date_string:0:4}-${date_string:4:2}-${date_string:6:2}" ;;
  10) echo "$date_string" ;;
  *)
    echo "Invalid date format" >&2
    echo "$date_string"
    ;;
  esac
}

read_yaml_as_json() {
  local input_file="$1"
  yq --output-format json '.[]' "$input_file" | jq -c 'to_entries | sort_by(.key) | from_entries'
}

write_json_as_yaml() {
  local output_file="$1"
  jq -s '.' | yq --input-format json --output-format yaml >"$output_file"
}

ensure_file_exists() {
  local file_path="$1"
  local dir_path

  dir_path=$(dirname "$file_path")

  # Create directory if it doesn't exist
  if [ ! -d "$dir_path" ]; then
    mkdir -p "$dir_path"
    echo "Created directory: $dir_path" >&2
  fi

  # Create file if it doesn't exist
  if [ ! -f "$file_path" ]; then
    echo "[]" >"$file_path"
    echo "Created empty YAML file: $file_path" >&2
  fi
}

#######################
# Metadata Handling
#######################

fetch_metadata() {
  local id="$1"
  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/yt-dlp/"
  local cache_file="$cache_dir/$id.json"

  mkdir -p "$cache_dir"

  if [[ -f "$cache_file" ]]; then
    cat "$cache_file"
  else
    yt-dlp --dump-single-json --flat-playlist "$id" | tee "$cache_file"
  fi
}

process_entry() {
  local entry="$1"
  local youtube_id

  youtube_id=$(echo "$entry" | jq -r '.ids.youtube // ""')

  if [ -n "$youtube_id" ]; then
    current_artist=$(echo "$entry" | jq -r '.artist // ""')
    current_album=$(echo "$entry" | jq -r '.album // ""')
    current_date=$(echo "$entry" | jq -r '.date // ""')

    if [ -z "$current_artist" ] || [ -z "$current_album" ] || [ -z "$current_date" ]; then
      metadata=$(fetch_metadata "$youtube_id")

      first_video_id=$(echo "$metadata" | jq -r '.entries[0].id // ""')
      item_metadata=$(fetch_metadata "$first_video_id")

      [ -z "$current_artist" ] && current_artist=$(echo "$item_metadata" | jq -r '.artist // ""')
      [ -z "$current_album" ] && current_album=$(echo "$item_metadata" | jq -r '.album // ""')
      [ -z "$current_date" ] && {
        current_date=$(echo "$item_metadata" | jq -r '.release_date // .upload_date // ""')
        current_date=$(format_date "$current_date")
      }

      entry=$(
        echo "$entry" |
          jq -c \
            --arg artist "$current_artist" \
            --arg album "$current_album" \
            --arg date "$current_date" \
            '. + {artist: $artist, album: $album, date: $date} | to_entries | sort_by(.key) | from_entries'
      )
    fi
  fi

  echo "$entry"
}

process_entries() {
  local input_file="$1"
  local temp_file
  temp_file="$(mktemp)"

  read_yaml_as_json "$input_file" |
    while read -r entry; do
      process_entry "$entry"
    done >"$temp_file"

  write_json_as_yaml "$input_file" <"$temp_file"
  rm "$temp_file"
}

#######################
# Command Functions
#######################

ids_command() {
  local input_file="$1"
  local source="$2"

  ensure_file_exists "$input_file"

  if [ -z "$source" ]; then
    echo "Error: Source not specified for 'ids' command." >&2
    print_usage
    exit 1
  fi

  yq --output-format json '.[]' "$input_file" |
    jq -r --arg source "$source" '.ids[$source] // empty' |
    sort | uniq
}

dump_command() {
  local input_file="$1"
  local format="$2"

  ensure_file_exists "$input_file"

  case "$format" in
  json)
    yq --output-format json '.' "$input_file"
    ;;
  jsonl)
    yq --output-format json '.' "$input_file" | jq -c '.[]'
    ;;
  *)
    echo "Error: Unsupported format '$format'. Supported formats are 'json' and 'jsonl'." >&2
    exit 1
    ;;
  esac
}

refresh_command() {
  local input_file="$1"

  ensure_file_exists "$input_file"

  echo "Processing entries..." >&2
  process_entries "$input_file"
  echo "Processing complete. Updated entries have been written to $input_file" >&2
}

add_command() {
  local input_file="$1"
  local key="$2"
  local value="${3:-}"

  ensure_file_exists "$input_file"

  if [ -z "${input_file:-}" ] || [ ! -f "$input_file" ]; then
    echo "Error: Input file '$input_file' not found or not specified." >&2
    print_usage
    exit 1
  fi

  # If only one parameter is provided, try to parse it
  if [ -z "$value" ]; then
    if [[ "$key" == *"youtube.com"* || "$key" == *"youtu.be"* ]]; then
      value=$(echo "$key" | sed -n 's/.*[?&]list=\([^&]*\).*/\1/p')
      key="youtube"
      if [ -z "$value" ]; then
        echo "Error: Could not extract playlist ID from the URL." >&2
        exit 1
      fi
    else
      echo "Error: Invalid input. Please provide either a key and value, or a YouTube playlist URL." >&2
      exit 1
    fi
  fi

  # Check if entry already exists
  if read_yaml_as_json "$input_file" | jq -e "select(.ids.$key == \"$value\")" >/dev/null 2>&1; then
    echo "Error: An entry with $key = $value already exists in the database." >&2
    exit 1
  fi

  new_entry=$(jq -c -n --arg key "$key" --arg value "$value" '{ids: {($key): $value}}')
  temp_file="$(mktemp)"

  read_yaml_as_json "$input_file" >"$temp_file"
  process_entry "$new_entry" >>"$temp_file"

  write_json_as_yaml "$input_file" <"$temp_file"
  rm "$temp_file"

  echo "New entry added and processed. Updated file: $input_file" >&2
}

######
# Main
######

DB="${XDG_DATA_HOME:-$HOME/.local/share}/deadwax/db.yaml"

if ! options=$(getopt -o d: -l database:,format: -- "$@"); then
  print_usage
  exit 1
fi
eval set -- "$options"

format="json"

while true; do
  case "$1" in
  -d | --database)
    DB="$2"
    shift 2
    ;;
  --format)
    format="$2"
    shift 2
    ;;
  --)
    shift
    break
    ;;
  *)
    print_usage
    exit 1
    ;;
  esac
done

# Check if a subcommand was provided
if [ $# -eq 0 ]; then
  echo "Error: No subcommand specified." >&2
  print_usage
  exit 1
fi

ensure_file_exists "$DB"

# Parse subcommand
subcommand="$1"
shift

case "$subcommand" in
refresh)
  refresh_command "$DB"
  ;;
add)
  if [ $# -eq 1 ]; then
    add_command "$DB" "$1"
  elif [ $# -eq 2 ]; then
    add_command "$DB" "$1" "$2"
  else
    echo "Error: The 'add' subcommand requires either one or two arguments." >&2
    print_usage
    exit 1
  fi
  ;;
ids)
  if [ $# -eq 1 ]; then
    ids_command "$DB" "$1"
  else
    echo "Error: The 'ids' subcommand requires exactly one argument." >&2
    print_usage
    exit 1
  fi
  ;;
dump)
  dump_command "$DB" "$format"
  ;;
*)
  echo "Error: Unknown subcommand '$subcommand'" >&2
  print_usage
  exit 1
  ;;
esac
