#!/usr/bin/env bash

###############################################################################
# Environment Variables
###############################################################################

: "${XDG_DATA_HOME:=$HOME/.local/share}"
: "${MUSICULL_DATABASE:=$XDG_DATA_HOME/musicull/db.yaml}"
export FZF_DEFAULT_OPTS="
  --pointer='›' \
  --marker='›' \
  --color=prompt:#7353db,pointer:#ad5d93,fg+:#c569a7,bg:-1,bg+:-1,gutter:-1,marker:#e178be,info:-1 \
  --preview-window='up:2:border-none' \
  --layout=reverse \
  --no-info \
  --header-first \
  --no-separator \
  ${FZF_DEFAULT_OPTS}
"

###############################################################################
# Help Documentation
###############################################################################

output_help() {
  cat <<EOF
Usage: $0 [--database|-d <database_file>] <subcommand>
Global options:
  -d, --database    Specify the input YAML file (default: ${MUSICULL_DATABASE})

Subcommands:
  add        Add a new entry to the database (placeholder)
             Usage: add <key> <value>
             Example: add ytmusic OLAK5uy_example1234
  dump       Dump the database content
             Usage: dump [format]
             Supported formats: json (default), jsonl
  delete     Delete entries by their source IDs
             Usage: del [<id> ...]
             If no IDs are provided, opens an interactive selection menu
             Example: del OLAK5uy_example1234 OLAK5uy_another5678
EOF
}

###############################################################################
# File Operations
###############################################################################

check_and_create_file() {
  local file_path="$1"
  local dir_path

  dir_path=$(dirname "$file_path")

  if [ ! -d "$dir_path" ]; then
    mkdir -p "$dir_path"
    gum log --level info "Created directory: $dir_path"
  fi

  if [ ! -f "$file_path" ]; then
    echo "---" >"$file_path"
    gum log --level info "Created YAML file: $file_path"
  fi

  # Validate YAML
  if ! yq eval-all '.' "$file_path" &>/dev/null; then
    gum log --level error "Invalid YAML file: $file_path"
    exit 1
  fi
}

###############################################################################
# Interactive Selection Functions
###############################################################################

format_artists() {
  local artists="$1"
  echo "$artists" | jq -r '
    map(.name) |
    if length == 1 then
      .[0]
    elif length == 2 then
      join(" & ")
    else
      .[0:-1] | join(", ") | . + " & " + .[-1]
    end
  '
}

get_interactive_selections() {
  local input_file="$1"

  # Process YAML to create formatted menu items and corresponding IDs
  local temp_file
  temp_file=$(mktemp)
  local preview_text=""

  yq eval-all \
    --output-format=json \
    "$input_file" |
    jq \
      --raw-output \
      '"\(.sources[].id)\t\(.name)\(.year | if . != null then " (" + tostring + ")" else "" end) - \(.artists | map(.name) | join(", "))"' |
    fzf \
      --multi \
      --with-nth 2.. \
      --prompt="Choose Album(s): " \
      --preview $'echo "\033[38;2;100;100;100m'"$preview_text"$'\033[0m"' \
      --preview-window=top:1 |
    cut -f1
}

###############################################################################
# Command Implementations
###############################################################################

process_deadwax_output() {
  local command="$1"
  shift

  {
    yq --output-format=json "$MUSICULL_DATABASE"
    DEADWAX_TARGET_OUTPUT=album \
      DEADWAX_MENU_ITEMS=artist,album \
      deadwax "$command" "$@" |
      jq '
        select(.)
        | del(.songs, .thumbnail)
      '
  } |
    jq --slurp '
      # Group by source IDs from any platform
      group_by(
        (.sources | to_entries | map(.value.id) | sort)[0]
      )

      # Merge objects in each group
      | map(
          reduce .[1:][] as $item (.[0];
            . * $item
          )
        )
      | .[]
    ' |
    yq \
      eval-all \
      --input-format=json \
      --output-format=yaml |
    sponge "$MUSICULL_DATABASE"
}

convert() {
  local format="$1"
  local input_file="$2"

  check_and_create_file "$input_file"

  case "$format" in
  yaml)
    yq --output-format=yaml "$input_file"
    ;;
  json)
    yq --output-format=json "$input_file" | jq --slurp
    ;;
  jsonl)
    yq --output-format=json "$input_file" | jq --compact-output
    ;;
  *)
    gum log --level error "Unsupported format '$format'. Supported formats are 'json' and 'jsonl'."
    exit 1
    ;;
  esac
}

delete_entries() {
  local input_file="$1"
  shift
  local ids=("$@")

  # If no IDs provided, use interactive selection
  if [ ${#ids[@]} -eq 0 ]; then
    local selected_ids
    selected_ids=$(get_interactive_selections "$input_file")
    if [ -z "$selected_ids" ]; then
      gum log --level warn "No entries selected for deletion."
      exit 0
    fi
    # Convert newline-separated IDs to array
    IFS=$'\n' read -d '' -r -a ids <<<"$selected_ids"
  fi

  # Convert ids array to JQ-compatible format
  local jq_ids_array
  printf -v jq_ids_array '"%s",' "${ids[@]}"
  jq_ids_array="[${jq_ids_array%,}]"

  # Create a temporary file
  local temp_file
  temp_file=$(mktemp)

  # Process each YAML document separately and maintain document separators
  yq eval-all --output-format=json "$input_file" |
    jq --arg ids "$jq_ids_array" --compact-output '
      def has_matching_id(entry; ids):
        entry.sources as $sources
        | (
            $sources
            | to_entries
            | map(.value.id)
          ) as $entry_ids
        | (
            $ids
            | fromjson
          )
          as $target_ids
        | (
            $entry_ids
            | any(
                . as $id
                | $target_ids
                | contains([$id])
              )
          )
        | not;

      select(has_matching_id(.; $ids))
    ' |
    while read -r line; do
      echo "$line" | yq eval --input-format=json --output-format=yaml - >>"$temp_file"
      echo "---" >>"$temp_file"
    done

  # Remove trailing separator if file is not empty
  if [ -s "$temp_file" ]; then
    sed -i '$ d' "$temp_file"
  fi

  # Move temporary file to original location
  mv "$temp_file" "$input_file"

  gum log --level info "Deleted entries with matching IDs: ${ids[*]}"
}

###############################################################################
# Command Line Argument Processing
###############################################################################

if ! options=$(getopt -o d: -l database: -- "$@"); then
  output_help
  exit 1
fi
eval set -- "$options"

while true; do
  case "$1" in
  -d | --database)
    MUSICULL_DATABASE="$2"
    shift 2
    ;;
  --)
    shift
    break
    ;;
  *)
    output_help
    exit 1
    ;;
  esac
done

###############################################################################
# Main Command Router
###############################################################################

# Check if a subcommand was provided
if [ $# -eq 0 ]; then
  gum log --level error "No subcommand specified."
  output_help
  exit 1
fi

check_and_create_file "$MUSICULL_DATABASE"

# Parse subcommand
subcommand="$1"
shift

case "$subcommand" in
search)
  process_deadwax_output "search" "$@"
  ;;
add)
  process_deadwax_output "show" "$@"
  ;;
dump)
  format="${1:-jsonl}"
  convert "$format" "$MUSICULL_DATABASE"
  ;;
del | d | delete)
  delete_entries "$MUSICULL_DATABASE" "$@"
  ;;
*)
  gum log --level error "Unknown subcommand '$subcommand'"
  output_help
  exit 1
  ;;
esac
