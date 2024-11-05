if [ ! -t 0 ]; then
  json_data=$(cat)
  if ! echo "$json_data" | jq . >/dev/null 2>&1; then
    gum log --level error "Invalid JSON input"
    exit 1
  fi

  # First aggregate the jsonl into a JSON array
  tracks_array=$(jq -s '.' <<<"$json_data")

  playlist_name=$(jq -r '.[0].album.name' <<<"$tracks_array")

  jq \
    --raw-output \
    --arg playlist "$playlist_name" '[
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
            "<playlist version=\"1\" xmlns=\"http://xspf.org/ns/0/\">",
            "  <title>\($playlist)</title>",
            "  <trackList>",
            (.[] |
                "    <track>",
                "      <location>https://youtube.com/watch?v=" + .sources.youtube.id + "</location>",
                "      <title>" + .title + "</title>",
                "      <creator>" + .album.artists[0].name + "</creator>",
                "      <album>" + .album.name + "</album>",
                "      <trackNum>" + (.order | tostring) + "</trackNum>",
                "      <duration>" + (.duration * 1000 | tostring) + "</duration>",
                "      <image>" + .thumbnail + "</image>",
                "    </track>"
            ),
            "  </trackList>",
            "</playlist>"
        ] | .[]' <<<"$tracks_array"
else
  gum log --level error "No JSON input detected. Please pipe JSON data to the script."
  exit 1
fi
