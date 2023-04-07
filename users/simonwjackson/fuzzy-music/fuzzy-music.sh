# This script has the following dependencies:
# beet - A music library manager and MediaWiki command line tool
# jq - A lightweight and flexible command-line JSON processor
# fzf - A general-purpose command-line fuzzy finder
# socat - A utility for data transfer between two addresses
# xargs - A utility to build and execute command lines from standard input
# awk - A text processing tool for scanning and processing text
# grep - A command-line utility for searching plain-text data for lines that match a regular expression
# sed - A stream editor used to perform basic text transformations on an input stream (a file or input from a pipeline)
# tr - A command-line utility for translating or deleting characters
# ssh - A secure shell for logging into and executing commands on a remote machine

# Set the shell to exit immediately if any command exits with a non-zero status
set -e

# Location of the MPV socket file can be defined in the mpv.conf file
socket_file="/run/user/1000/mpv.socket"

# Define the remote hosts. The remote hosts must have `beet` installed
remote_host="unzen"

# Display the usage message
function usage() {
  cat << EOF
  Usage: $(basename "$0") [options]

  This script exports album data from two beet databases, processes the JSON output,
  and uses fzf to display and search the albums. The selected album is then played
  using MPV through a socket.

  Options:
  -h, --help      Show this help message and exit.

  Example:
  $(basename "$0")

EOF
}

# Parse the command line options
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# Export album data using beet export
function beet_export() {
  location="$1"
  beet_include='id,year,album,albumartist'
  album_json='{ "data": del(.id), "meta": { "source": "beets", "id": .id, "location": "'$location'"} }' 

  # Run the beet export command and process the JSON output
  ( ssh "$location" -- beet export \
    --album \
    --include "$beet_include" \
    --format jsonlines \
    | jq \
    --raw-output \
    --compact-output \
    "$album_json" 
  )
}

# Format the album data for fzf display
function fzf_format () {
  format='"\(.data.album) - \(.data.albumartist) [\(.data.year)]\t\(.)"' 

  # Use jq to format the JSON data for fzf
  ( jq \
    --compact-output \
    --raw-output \
    "$format"
  )
}

# fzf options and display prompt
function fzf_prompt () {
  ( fzf \
    --ansi \
    --prompt=" > " \
    --header-lines=1 \
    --delimiter=$'\t' \
    --with-nth=1 \
    --layout=default
  )
}

# Extract the album ID from the JSON data
function get_album_id () {
  ( jq \
    --raw-output \
    '.meta.id'
  )
}

# Print only the JSON column from the input
function only_json_column () {
  ( awk \
    -F '\t' \
    '{print $2}' \
    | grep '.' \
  )
}

# Define a function to prefer local files when there are duplicates
function prefer_local_files () {
  query='group_by(.data) | map( if length > 1 then map(select(.meta.location == "local")) | add else .[0] end) | .[]';

  ( jq \
    --slurp \
    --compact-output \
    "$query"
  )
}

# Run the beet_export function for `localhost` and `unzen in parallel and prefer local files
{ beet_export "localhost" & \
  beet_export $remote_host & 
} | prefer_local_files \
  | fzf_format \
  | {
  # Display the header row in fzf
  cat & \
  echo "Album - Artist [Year]" &
} | fzf_prompt \
  | only_json_column \
  | {
  while read -r json; do
    # Get the album ID and host from the JSON data
    album_id=$(jq -r '.meta.id' <<< "$json")
    # Get the host from the JSON data
    host=$(jq -r '.meta.location' <<< "$json")
    # Format the path for MPV
    format="\"sftp://${host}/\\\$path\""

    # Send commands to MPV using the socket, to stop the current playlist and clear the playlist
    echo '{ "command": ["stop"] }' | socat - "$socket_file"
    echo '{ "command": ["playlist-clear"] }' | socat - "$socket_file"

    # Get the list of songs for the selected album and send them to MPV
    ( ssh -n "$host" \
      -- beet ls \
      --format "$format" \
      album_id:"$album_id" \
      | tr '\n' '\0' \
      | xargs -0 -I {} echo '{ "command": ["loadfile", "{}", "append-play"] }' \
      | socat - "$socket_file"
    )
  done
}
