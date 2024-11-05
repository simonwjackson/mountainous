if [ ! -t 0 ]; then
  json_data=$(cat)
  if ! echo "$json_data" | jq . >/dev/null 2>&1; then
    gum log --level error "Invalid JSON input"
    exit 1
  fi

  # First aggregate the jsonl into a JSON array
  tracks_array=$(jq -s '.' <<<"$json_data")

  # Use first track's album as playlist name
  playlist_name=$(jq -r '.[0].album.name' <<<"$tracks_array")

  # Output m3u8 format
  jq \
    --raw-output \
    --arg playlist "$playlist_name" \
    '[
            "#EXTM3U",
            "#PLAYLIST:\($playlist)",
            "#EXTENC:UTF-8",
            (.[] |
                "#EXTINF:" + (.duration | tostring) + "," + (.order | tostring) + ". " + (.album.artists[0].name) + " - " + .title,
                "#EXTALB:" + .album.name,
                "#EXTART:" + .album.artists[0].name,
                "#EXTIMG:" + .thumbnail,
                "#YTTITLE:" + .title,
                "#YTID:" + .sources.youtube.id,
                "https://youtube.com/watch?v=" + .sources.youtube.id,
                ""
            )
        ] | .[]' <<<"$tracks_array"
else
  gum log --level error "No JSON input detected. Please pipe JSON data to the script."
  exit 1
fi
