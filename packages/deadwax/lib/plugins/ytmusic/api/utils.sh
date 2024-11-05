mpreb_to_olak() {
  local str=$1

  # Return input string if it doesn't start with MPREb_
  if [[ ! "$str" =~ ^MPREb_ ]]; then
    echo "$str"
    return
  fi

  ytapi --cache browse '{
    "browseId": "'"$str"'",
    "context": {
      "client": {
        "originalUrl": "https://music.youtube.com/library"
      }
    }
  }' \
    --header 'Referer: https://music.youtube.com/library' |
    jq \
      --compact-output \
      --raw-output \
      --from-file "$(dirname "${BASH_SOURCE[0]}")/mpreb-to-olak.jq"
}
export -f mpreb_to_olak

get_special_artist_id() {
  local artist_id="$1"
  local recommend="${2:-false}"
  local playlist_pattern

  # Set pattern based on whether we want recommendations
  if [ "$recommend" == "false" ] || [ "$recommend" == "true" ]; then
    playlist_pattern='(?<=\\x22playlistId\\x22:\\x22)RDEM\w+'
  else
    playlist_pattern='(?<=\\x22playlistId\\x22:\\x22)RDAO\w+'
  fi

  # Fetch the initial playlist ID
  local playlist_id
  playlist_id="$(
    curl -s "https://music.youtube.com/channel/$artist_id" \
      --compressed \
      --header 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:131.0) Gecko/20100101 Firefox/131.0' |
      grep -oP "$playlist_pattern" |
      tail -n 1
  )"

  # If no playlist ID found
  if [[ -z "$playlist_id" ]]; then
    echo "Error: Could not find playlist ID for artist $artist_id" >&2
    return 1
  fi

  # For tagged recommendations, we need to do additional processing
  if [ "$recommend" != "false" ] && [ "$recommend" != "true" ]; then
    local result

    result="$(ytapi next '{
      "playlistId": "'"$playlist_id"'"
    }' | jq --raw-output '(
      .contents
      .singleColumnMusicWatchNextResultsRenderer
      .tabbedRenderer
      .watchNextTabbedResultsRenderer
      .tabs[0]
      .tabRenderer
      .content
      .musicQueueRenderer
      .subHeaderChipCloud
      .chipCloudRenderer
      .chips[1]
      .chipCloudChipRenderer
      .navigationEndpoint
      .queueUpdateCommand
      .fetchContentsCommand
      .watchEndpoint
      .playlistId
      | capture(
        "RDAT.*?s(?<result>.*)"
      )
      .result
    )')"

    if [[ -z "$result" ]]; then
      echo "Error: Could not extract tagged ID from playlist" >&2
      return 1
    fi

    echo "$result"
  else
    echo "${playlist_id:4}"
  fi
}

extract_id() {
  local url="$1"
  local pattern="$2"

  echo "$url" | grep -oP "$pattern"
}

evolve_id() {
  local string=$1
  local id=""
  local type=""

  if [[ "$string" =~ ^https://music\.youtube\.com/channel/UC[a-zA-Z0-9_-]{22}($|\?) ]] || [[ "$string" =~ ^UC[a-zA-Z0-9_-]{22}$ ]]; then
    type="artist"
    id=$(extract_id "$string" 'UC[a-zA-Z0-9_-]{22}') || id="$string"
  elif [[ "$string" =~ ^(https://music\.youtube\.com/playlist\?list=)?OLAK5uy_[A-Za-z0-9_-]{33}$ ]]; then
    type="album"
    id=$(extract_id "$string" '(?<=list=)OLAK5uy_[A-Za-z0-9_-]{33}(?=&|$)') || id="$string"
  elif [[ "$string" =~ ^https://music\.youtube\.com/browse/MPREb_ || "$string" =~ ^MPREb_[a-zA-Z0-9_-]+$ ]]; then
    type="album"
    mpreb_album_id=$(extract_id "$string" 'MPREb_[a-zA-Z0-9_-]+') || id="$string"
    id=$(mpreb_to_olak "$mpreb_album_id")
  elif [[ "$string" =~ ^https://music\.youtube\.com/playlist\?list=RDCLAK5uy_[A-Za-z0-9_-]{33}($|\?) ]] || [[ "$string" =~ ^RDCLAK5uy_[A-Za-z0-9_-]{33}$ ]]; then
    type="playlist"
    id=$(extract_id "$string" 'RDCLAK5uy_[A-Za-z0-9_-]{33}') || id="$string"
  elif [[ "$string" =~ ^https://music\.youtube\.com/playlist\?list=PL[A-Za-z0-9_-]{32}($|\?) ]] || [[ "$string" =~ ^PL[A-Za-z0-9_-]{32}$ ]]; then
    type="playlist"
    id=$(extract_id "$string" 'PL[A-Za-z0-9_-]{32}') || id="$string"
  elif [[ "$string" =~ ^https://music\.youtube\.com/watch\?v= || "$string" =~ ^[a-zA-Z0-9_-]{11}$ ]]; then
    type="song"
    id=$(extract_id "$string" '(?<=v=)[a-zA-Z0-9_-]{11}') || id="$string"
  else
    echo '{ "error": "Invalid id format" }' >&2
    return 1
  fi

  jq \
    -n \
    --arg value "$id" \
    --arg type "$type" '{
      "value": $value,
      "type": $type
    }'
}

# Constants for playlist ID components
readonly PLAYLIST_PREFIX="RD"

# Maps type and recommend combinations to their base types
get_base_type() {
  local type=$1
  local recommend=$2

  case "$type:$recommend" in
  "artist:true") echo "EM" ;;
  "artist:tag") echo "AT" ;;
  "album:true") echo "AMPL" ;;
  "song:true") echo "AMVM" ;;
  "song:tag") echo "AT" ;;
  *) echo "" ;;
  esac
}

# Gets the separator based on content type
get_separator() {
  local type=$1
  local recommend=$2

  [[ "$recommend" == "tag" ]] || return 0

  case "$type" in
  "artist") echo "a" ;;
  "song") echo "v" ;;
  *) echo "" ;;
  esac
}

buildPlaylistId() {
  local obj=$1
  local type id recommend

  # Parse JSON input
  eval "$(jq -r '@sh "
        type=\(.target.type)
        id=\(.target.value)
        recommend=\(.options.recommend // false)
    "' <<<"$obj")"

  # Return direct ID for playlists or non-recommended albums
  if [[ "$type" == "playlist" ]] || { [[ "$recommend" == "false" ]] && [[ "$type" == "album" ]]; }; then
    echo "$id"
    return 0
  fi

  # Handle special artist IDs
  [[ "$type" == "artist" ]] && id=$(get_special_artist_id "$id" "$recommend")

  # Validate input
  if [[ -z "$id" ]] || [[ -z "$type" ]]; then
    echo "Error: id and type is required" >&2
    return 1
  fi

  # Handle tagged album recommendations error case
  if [[ "$type" == "album" ]] && [[ "$recommend" == "tag" ]]; then
    echo "ERROR: Tagged album recommendations are not supported" >&2
    return 1
  fi

  # Convert recommend boolean/string to normalized value
  local recommend_type
  case "$recommend" in
  "true") recommend_type="true" ;;
  "false") recommend_type="false" ;;
  *) recommend_type="tag" ;;
  esac

  # Build playlist ID components
  local base_type
  base_type=$(get_base_type "$type" "$recommend_type")

  local separator
  separator=$(get_separator "$type" "$recommend_type")

  local tag_code
  tag_code=$(encodeTagId "$recommend")

  # Construct and return the final playlist ID
  echo "${PLAYLIST_PREFIX}${base_type}${tag_code}${separator}${id}"
}

encodeTagId() {
  case "$1" in
  # Intent
  discover) echo "iX" ;;
  familiar) echo "iY" ;;

  # Popularity
  deep-cuts) echo "pX" ;;
  popular) echo "pY" ;;

  # Moods
  chill) echo "mX" ;;
  pumpup) echo "mY" ;;
  workout) echo "mZ" ;;
  upbeat) echo "mb" ;;
  party) echo "me" ;;
  sleep) echo "mf" ;;
  romance) echo "md" ;;
  focus) echo "ma" ;;
  downbeat) echo "mc" ;;

  # Genres
  blues) echo "gb" ;;
  j-pop) echo "gx" ;;
  electronic) echo "gi" ;;
  hiphop) echo "grv" ;;
  instrumental) echo "nX" ;;
  jazz) echo "gy" ;;
  korean-dance) echo "g0X" ;;
  metal) echo "g6X" ;;
  indie) echo "gX" ;;
  folk) echo "gj" ;;
  kids) echo "gd" ;;
  pop) echo "g9X" ;;
  rb) echo "gBX" ;;
  reggae) echo "gCX" ;;
  rock) echo "gFX" ;;
  soundtracks) echo "gKX" ;;

  *) echo "" ;;
  esac
}
