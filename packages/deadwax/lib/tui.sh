: "${DEADWAX_MENU_ITEMS:="artist,album,playlist,song"}"
: "${DEADWAX_TARGET_OUTPUT:="song"}"
: "${FZF_DEFAULT_OPTS:=""}"

while [[ $# -gt 0 ]]; do
  case $1 in
  --target)
    DEADWAX_TARGET_OUTPUT="$2"
    shift 2
    ;;
  *)
    break
    ;;
  esac
done

# Validate DEADWAX_TARGET_OUTPUT if provided
if [ -n "$DEADWAX_TARGET_OUTPUT" ]; then
  case "$DEADWAX_TARGET_OUTPUT" in
  artist | album | playlist | song) ;;
  *)
    echo "Error: Invalid target output. Must be one of: artist, album, playlist, song" >&2
    exit 1
    ;;
  esac
fi

export DEADWAX_TARGET_OUTPUT

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

##########
# List
#########

list() {
  local type="$1"
  shift
  local ids="$*"

  case "$type" in
  song | playlist | album | artist)
    echo "$ids" |
      tr ' ' '\n' |
      xargs -I {} bash -c "get $type {}" |
      choose "${type}"
    # xargs -P8 -I{} sh -c "get $type {}" |
    ;;
  *)
    echo "Error: Invalid type. Must be one of: song, playlist, album, artist" >&2
    return 1
    ;;
  esac
}

##########
# Get
##########

get() {
  local resource="$1"
  shift
  local ids="$*"

  # Validate resource type
  case "$resource" in
  song | artist | playlist | album)
    echo "$ids" |
      tr ' ' '\n' |
      xargs -P8 -I{} "${DEADWAX_BASE_DIR}/../lib/cli.sh" "$resource" "{}"
    ;;
  *)
    echo "Error: Invalid resource type. Must be one of: song, artist, playlist, album" >&2
    return 1
    ;;
  esac
}

#############
# Choose
#############

choose() {
  local type=$1
  local bindings=()
  local preview_text=""
  local jq_filter=""
  local action_command=""

  preview_text="↑/↓: navigate | enter: "

  case "$type" in
  "artist")
    preview_text+="$([[ "$DEADWAX_TARGET_OUTPUT" == "artist" ]] && echo "get artist" || echo "view album")"
    jq_filter='"\(.id)\t\(.name)"'
    if [[ "$DEADWAX_TARGET_OUTPUT" == "artist" ]]; then
      action_command="echo {+1} | xargs -I % bash -c 'get artist \"%\"'"
    else
      action_command="echo {+1} | xargs -I % bash -c 'list album \"%\"'"
    fi
    ;;
  "album")
    preview_text+="$([[ "$DEADWAX_TARGET_OUTPUT" == "album" ]] && echo "get album" || echo "view song")"
    jq_filter='"\(.id)\t\(.name) (\(.year)) - \(.artists | map(.name) | join(", "))"'
    if [[ "$DEADWAX_TARGET_OUTPUT" == "album" ]]; then
      action_command="echo {+1} | xargs -I % bash -c 'get album \"%\"'"
    else
      action_command="echo {+1} | xargs -I % bash -c 'list song \"%\"'"
    fi
    ;;
  "song")
    preview_text+="$([[ "$DEADWAX_TARGET_OUTPUT" == "song" ]] && echo "get song" || echo "view artist")"
    jq_filter='"\(.sources.youtube.id)\t\(.order) \(.title)"'
    if [[ "$DEADWAX_TARGET_OUTPUT" == "song" ]]; then
      action_command="echo {+1} | xargs -I % bash -c 'get song \"%\"'"
    else
      action_command="echo {+1} | xargs -I % bash -c 'list artist \"%\"'"
    fi
    ;;
  "playlist")
    preview_text+="$([[ "$DEADWAX_TARGET_OUTPUT" == "playlist" ]] && echo "get playlist" || echo "view playlist")"
    jq_filter='"\(.id)\t\(.name)"'
    if [[ "$DEADWAX_TARGET_OUTPUT" == "playlist" ]]; then
      action_command="echo {+1} | xargs -I % bash -c 'get playlist \"%\"'"
    else
      action_command="echo {+1} | xargs -I % bash -c 'list playlist \"%\"'"
    fi
    ;;
  *)
    echo "Invalid type. Use: artist, album, song, or playlist"
    return 1
    ;;
  esac

  bindings=("--bind=enter:become($action_command)+abort")

  jq \
    --raw-output \
    "$jq_filter" |
    fzf \
      --multi \
      --with-nth 2.. \
      --prompt="Choose $type: " \
      --preview $'echo "\033[38;2;100;100;100m'"$preview_text"$'\033[0m"' \
      --preview-window=top:1 \
      "${bindings[@]}"
}

##############
# Search
##############

search() {
  local type="$1"
  local query="$2"
  local choose_type="${type}"

  if [ -z "$query" ]; then
    query=$(gum input --placeholder "Search ${type}...")
  fi

  if [ -n "$query" ]; then
    "${DEADWAX_BASE_DIR}/../lib/cli.sh" search "$type" "$query" |
      choose "$choose_type"
  fi
}

##############
# Main
##############

search_menu() {
  # Handle direct option and query
  if [ $# -ge 1 ]; then
    local option="$1"
    local query="$2"

    # Check if the option is in DEADWAX_MENU_ITEMS
    if [[ ",${DEADWAX_MENU_ITEMS}," == *",${option},"* ]]; then
      search "$option" "$query"
      exit 0
    else
      echo "Error: Invalid option. Must be one of: ${DEADWAX_MENU_ITEMS}" >&2
      exit 1
    fi
  fi

  local selected_option

  selected_option=$(
    printf "%s\n" "${DEADWAX_MENU_ITEMS//,/$'\n'}" |
      fzf \
        --prompt="Search: " \
        --preview $'echo "\033[38;2;100;100;100m↑/↓: navigate | enter submit\033[0m"'
  )

  preview_text="↑/↓: navigate | enter: "

  case "$selected_option" in
  "artist")
    search artist
    ;;
  "album")
    search album
    ;;
  "playlist")
    search playlist
    ;;
  "song")
    search song
    ;;
  esac
}

export -f search list choose get

search_menu "$@"
