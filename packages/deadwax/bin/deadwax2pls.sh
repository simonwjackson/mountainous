if [ ! -t 0 ]; then
  json_data=$(cat)
  if ! echo "$json_data" | jq . >/dev/null 2>&1; then
    gum log --level error "Invalid JSON input"
    exit 1
  fi

  # First aggregate the jsonl into a JSON array
  tracks_array=$(jq -s '.' <<<"$json_data")

  {
    echo "[playlist]"
    echo "NumberOfEntries=$(jq 'length' <<<"$tracks_array")"
    echo "Version=2"
    echo
    jq -r '
            to_entries[] |
            . as $entry |
            [
                "File" + (($entry.key + 1) | tostring) + "=https://youtube.com/watch?v=" + .value.sources.youtube.id,
                "Title" + (($entry.key + 1) | tostring) + "=" + (.value.order | tostring) + ". " + .value.album.artists[0].name + " - " + .value.title,
                "Length" + (($entry.key + 1) | tostring) + "=" + (.value.duration | tostring)
            ] | .[]
        ' <<<"$tracks_array"
  }
else
  gum log --level error "No JSON input detected. Please pipe JSON data to the script."
  exit 1
fi
