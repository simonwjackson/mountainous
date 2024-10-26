format_output() {
  local format="$1"
  local json_data

  # Read JSON from stdin
  json_data=$(cat)

  case "$format" in
  m3u8)
    # First aggregate the jsonl into a JSON array
    local tracks_array
    tracks_array=$(jq -s '.' <<<"$json_data")

    # Use first track's album as playlist name
    local playlist_name
    playlist_name=$(jq -r '.[0].album' <<<"$tracks_array")

    # Output m3u8 format
    jq \
      --raw-output \
      --arg playlist "$playlist_name" \
      '[
        "#EXTM3U",
        "#PLAYLIST:\($playlist)",
        "#EXTENC:UTF-8",
        (.[] |
          "#EXTINF:" + .duration + "," + (.track | tostring) + ". " + .artist + " - " + .title,
          "#EXTALB:" + .album,
          "#EXTART:" + .artist,
          "#EXTIMG:" + .thumbnail,
          "#YTTITLE:" + .title,
          "#YTID:" + .source_id,
          .url,
          ""
        )
      ] | .[]' <<<"$tracks_array"
    ;;
  xspf)
    # First aggregate the jsonl into a JSON array
    local tracks_array
    tracks_array=$(jq -s '.' <<<"$json_data")

    local playlist_name
    playlist_name=$(jq -r '.[0].album' <<<"$tracks_array")

    jq \
      --raw-output \
      --arg playlist "$playlist_name" '[
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
        "<playlist version=\"1\" xmlns=\"http://xspf.org/ns/0/\">",
        "  <title>\($playlist)</title>",
        "  <trackList>",
        (.[] |
          "    <track>",
          "      <location>" + .url + "</location>",
          "      <title>" + .title + "</title>",
          "      <creator>" + .artist + "</creator>",
          "      <album>" + .album + "</album>",
          "      <trackNum>" + (.track | tostring) + "</trackNum>",
          "      <duration>" + (.duration | tonumber * 1000 | tostring) + "</duration>",
          "      <image>" + .thumbnail + "</image>",
          "    </track>"
        ),
        "  </trackList>",
        "</playlist>"
      ] | .[]' <<<"$tracks_array"
    ;;
  pls)
    # First aggregate the jsonl into a JSON array
    local tracks_array
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
          "File" + (($entry.key + 1) | tostring) + "=" + .value.url,
          "Title" + (($entry.key + 1) | tostring) + "=" + (.value.track | tostring) + ". " + .value.artist + " - " + .value.title,
          "Length" + (($entry.key + 1) | tostring) + "=" + .value.duration
        ] | .[]
      ' <<<"$tracks_array"
    }
    ;;
  csv)
    # First aggregate the jsonl into a JSON array
    local tracks_array
    tracks_array=$(jq -s '.' <<<"$json_data")

    {
      # Header
      echo "Track,Title,Artist,Album,Duration,URL"
      # Data rows
      jq -r '.[] | [.track, .title, .artist, .album, .duration, .url] | @csv' <<<"$tracks_array"
    }
    ;;
  json)
    jq -s '.' <<<"$json_data"
    ;;
  jsonl)
    jq -c <<<"$json_data"
    ;;
  *)
    log error "Unsupported format: $format"
    return 1
    ;;
  esac
}
