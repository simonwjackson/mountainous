format_output() {
  local format=${1:-jsonl}
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
    ;;
  xspf)
    # First aggregate the jsonl into a JSON array
    local tracks_array
    tracks_array=$(jq -s '.' <<<"$json_data")

    local playlist_name
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
          "File" + (($entry.key + 1) | tostring) + "=https://youtube.com/watch?v=" + .value.sources.youtube.id,
          "Title" + (($entry.key + 1) | tostring) + "=" + (.value.order | tostring) + ". " + .value.album.artists[0].name + " - " + .value.title,
          "Length" + (($entry.key + 1) | tostring) + "=" + (.value.duration | tostring)
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
      echo "Track,Title,Artist,Album,Year,Duration,URL"
      # Data rows
      jq -r '.[] | [
        .order,
        .title,
        .album.artists[0].name,
        .album.name,
        .album.year,
        .duration,
        "https://youtube.com/watch?v=" + .sources.youtube.id
      ] | @csv' <<<"$tracks_array"
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
