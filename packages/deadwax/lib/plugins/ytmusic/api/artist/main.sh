album_search() {
  local query=$1

  ytapi search '{
    "query": "'"$query"'",
    "params": "EgWKAQIYAWoOEAMQBBAJEAoQERAQEBU%3D",
    "context": {
      "client": {
        "originalUrl": "https://music.youtube.com/library"
      }
    }
  }' \
    --header "Referer: https://music.youtube.com/library" |
    jq \
      --compact-output \
      --from-file "$(dirname "${BASH_SOURCE[0]}")/album-search.jq"
}

artist_albums() {
  local artistId=$1

  ytapi browse '{
    "browseId": "MPAD'"$artistId"'",
    "context": {
      "client": {
        "originalUrl": "https://music.youtube.com/channel/'"$artistId"'"
      }
    }
  }' \
    --header "Referer: https://music.youtube.com/channel/$artistId" |
    jq \
      --compact-output \
      --arg artistId "$artistId" \
      --from-file "$(dirname "${BASH_SOURCE[0]}")/artist-albums.jq"
}

playlist_search() {
  local query=$1

  {
    ytapi search '{
      "query": "'"$query"'",
      "params": "EgeKAQQoAEABahAQAxAEEAkQChAFEBEQEBAV",
      "context": {
        "client": {
          "originalUrl": "https://music.youtube.com/library"
        }
      }
    }' \
      --header "Referer: https://music.youtube.com/library"

    ytapi search '{
      "query": "'"$query"'",
      "params": "EgeKAQQoADgBahIQAxAEEAkQDhAKEAUQERAQEBU%3D",
      "context": {
        "client": {
          "originalUrl": "https://music.youtube.com/library"
        }
      }
    }' \
      --header "Referer: https://music.youtube.com/library"
  } |
    jq \
      --compact-output \
      --from-file "$(dirname "${BASH_SOURCE[0]}")/playlist-search.jq"
}

song_search() {
  local query=$1

  ytapi search '{
    "query": "'"$query"'",
    "params": "EgWKAQIIAWoQEAMQBBAJEAoQBRAREBAQFQ%3D%3D",
    "context": {
      "client": {
        "originalUrl": "https://music.youtube.com/library"
      }
    }
  }' \
    --header "Referer: https://music.youtube.com/library" |
    jq \
      --compact-output \
      --from-file "$(dirname "${BASH_SOURCE[0]}")/song-search.jq"
}

artist_search() {
  local artist=$1

  ytapi search '{
    "query": "'"$artist"'",
    "params": "EgWKAQIgAWoQEAMQBBAJEAoQBRAREBAQFQ%3D%3D",
    "context": {
      "client": {
        "originalUrl": "https://music.youtube.com/library"
      }
    }
  }' \
    --header "Referer: https://music.youtube.com/library" |
    jq \
      --compact-output \
      --from-file "$(dirname "${BASH_SOURCE[0]}")/artist-search.jq"
}

get_continuation() {
  echo "$1" |
    jq \
      -r '
        .continuationContents?
        .musicPlaylistShelfContinuation?
        .continuations[0]?
        .nextContinuationData?
        .continuation //
        .contents?
        .singleColumnBrowseResultsRenderer?
        .tabs[0]?
        .tabRenderer?
        .content?
        .sectionListRenderer?
        .contents[0]?
        .musicPlaylistShelfRenderer?
        .continuations[0]?
        .nextContinuationData?
        .continuation //
        empty
      '
}

# Function to make the initial API call
make_initial_call() {
  browseId=$1

  curl \
    'https://music.youtube.com/youtubei/v1/browse?prettyPrint=false' \
    --compressed \
    -X POST \
    -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:131.0) Gecko/20100101 Firefox/131.0' \
    -H 'Accept: */*' \
    -H 'Accept-Language: en-US,en;q=0.5' \
    -H 'Accept-Encoding: gzip, deflate, br, zstd' \
    -H 'Referer: https://music.youtube.com/channel/UCchSBquRGyKLijWxJhiUxyQ' \
    -H 'Content-Type: application/json' \
    -H 'X-Youtube-Bootstrap-Logged-In: false' \
    -H 'X-Youtube-Client-Name: 67' \
    -H 'X-Youtube-Client-Version: 1.20241028.01.00' \
    -H 'Origin: https://music.youtube.com' \
    -H 'DNT: 1' \
    -H 'Sec-GPC: 1' \
    -H 'Connection: keep-alive' \
    -H 'Sec-Fetch-Dest: empty' \
    -H 'Sec-Fetch-Mode: same-origin' \
    -H 'Sec-Fetch-Site: same-origin' \
    -H 'Priority: u=0' \
    -H 'TE: trailers' \
    --data-raw '{
      "browseId": "'"$browseId"'",
      "params": "ggMCCAI%3D",
      "context": {
        "client": {
          "hl": "en",
          "gl": "US",
          "remoteHost": "45.20.193.255",
          "deviceMake": "",
          "deviceModel": "",
          "userAgent": "Mozilla/5.0 (X11; Linux x86_64; rv:131.0) Gecko/20100101 Firefox/131.0,gzip(gfe)",
          "clientName": "WEB_REMIX",
          "clientVersion": "1.20241028.01.00",
          "osName": "X11",
          "osVersion": "",
          "originalUrl": "https://music.youtube.com/playlist?list=OLAK5uy_nwYNSdFlj62YfTpdzN1-hS3aSJupdZBuU",
          "platform": "DESKTOP",
          "clientFormFactor": "UNKNOWN_FORM_FACTOR",
          "configInfo": {
          },
          "userInterfaceTheme": "USER_INTERFACE_THEME_DARK",
          "timeZone": "America/Chicago",
          "browserName": "Firefox",
          "browserVersion": "131.0",
          "acceptHeader": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/png,image/svg+xml,*/*;q=0.8",
        },
        "user": {
          "lockedSafetyMode": false
        },
        "request": {
          "useSsl": true,
          "internalExperimentFlags": [],
          "consistencyTokenJars": []
        }
      }
    }'
}

# Function to make continuation calls
make_continuation_call() {
  local continuation="$1"
  local browseId="$2"

  curl \
    -s "https://music.youtube.com/youtubei/v1/browse?ctoken=${continuation}&continuation=${continuation}&type=next&prettyPrint=false" \
    --compressed \
    -X POST \
    -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:131.0) Gecko/20100101 Firefox/131.0' \
    -H 'Accept: */*' \
    -H 'Accept-Language: en-US,en;q=0.5' \
    -H 'Accept-Encoding: gzip, deflate, br, zstd' \
    -H "Referer: https://music.youtube.com/playlist?list=${browseId}" \
    -H 'Content-Type: application/json' \
    -H 'X-Youtube-Bootstrap-Logged-In: false' \
    -H 'X-Youtube-Client-Name: 67' \
    -H 'X-Youtube-Client-Version: 1.20241028.01.00' \
    -H 'Origin: https://music.youtube.com' \
    -H 'DNT: 1' \
    -H 'Sec-GPC: 1' \
    -H 'Connection: keep-alive' \
    -H 'Sec-Fetch-Dest: empty' \
    -H 'Sec-Fetch-Mode: same-origin' \
    -H 'Sec-Fetch-Site: same-origin' \
    -H 'Priority: u=4' \
    -H 'TE: trailers' \
    --data-raw '{
      "context": {
        "client": {
          "hl": "en",
          "gl": "US",
          "remoteHost": "1.1.1.1",
          "deviceMake": "",
          "deviceModel": "",
          "userAgent": "Mozilla/5.0 (X11; Linux x86_64; rv:131.0) Gecko/20100101 Firefox/131.0,gzip(gfe)",
          "clientName": "WEB_REMIX",
          "clientVersion": "1.20241028.01.00",
          "osName": "X11",
          "osVersion": "",
          "originalUrl": "https://music.youtube.com/playlist?list=OLAK5uy_nHfrvHAX60GB1k8Qq_Hj-atV-3hF44HSs",
          "platform": "DESKTOP",
          "clientFormFactor": "UNKNOWN_FORM_FACTOR",
          "configInfo": { },
          "userInterfaceTheme": "USER_INTERFACE_THEME_DARK",
          "timeZone": "America/Chicago",
          "browserName": "Firefox",
          "browserVersion": "131.0",
          "acceptHeader": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/png,image/svg+xml,*/*;q=0.8",
        },
        "user": {
          "lockedSafetyMode": false
        },
        "request": {
          "useSsl": true,
          "internalExperimentFlags": [],
          "consistencyTokenJars": []
        }
      }
    }'
}

get_artist_browse_id() {
  local artistId=$1

  curl "https://music.youtube.com/channel/$artistId" \
    --compressed \
    -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:131.0) Gecko/20100101 Firefox/131.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/png,image/svg+xml,*/*;q=0.8' \
    -H 'Accept-Language: en-US,en;q=0.5' \
    -H 'Accept-Encoding: gzip, deflate, br, zstd' \
    -H 'DNT: 1' \
    -H 'Sec-GPC: 1' \
    -H 'Connection: keep-alive' \
    -H 'Upgrade-Insecure-Requests: 1' \
    -H 'Sec-Fetch-Dest: document' \
    -H 'Sec-Fetch-Mode: navigate' \
    -H 'Sec-Fetch-Site: none' \
    -H 'Sec-Fetch-User: ?1' \
    -H 'Priority: u=0, i' \
    -H 'TE: trailers' |
    grep -oP 'VLOLAK5uy_.{33}' |
    head -n 1
}

get_artist_songs() {
  local artistId=$1

  {
    browseId=$(get_artist_browse_id "$artistId")
    response=$(make_initial_call "$browseId")

    echo "$response" | jq '
      .contents
      .singleColumnBrowseResultsRenderer
      .tabs[0]
      .tabRenderer
      .content
      .sectionListRenderer
      .contents[0]
      .musicPlaylistShelfRenderer
      .contents[]
    '

    continuation=$(get_continuation "$response")

    call_count=1
    while [ -n "$continuation" ]; do
      sleep 1

      response=$(make_continuation_call "$continuation" "$browseId")
      echo "$response" | jq '
        .continuationContents
        .musicPlaylistShelfContinuation
        .contents[]
      '
      continuation=$(get_continuation "$response")

      ((call_count++))
    done
  } |
    jq \
      --compact-output \
      --from-file "$(dirname "${BASH_SOURCE[0]}")/browse-to-songs.jq"
}
