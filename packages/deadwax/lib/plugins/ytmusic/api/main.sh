ytapi() {
  # Check for --cache flag immediately after function name
  local use_cache=false
  if [[ "$1" == "--cache" ]]; then
    use_cache=true
    shift
  fi

  local command=$1
  local data_raw=$2
  shift 2

  # Create cache directory if it doesn't exist
  local cache_dir=~/.cache/deadwax/ytmusic
  if [[ "$use_cache" == true ]]; then
    mkdir -p "$cache_dir"
  fi

  # Generate cache filename from command and data_raw
  local cache_file=""
  if [[ "$use_cache" == true ]]; then
    local hash=$(echo "${command}${data_raw}" | sha256sum | cut -d' ' -f1)
    cache_file="${cache_dir}/${hash}"

    # Return cached content if it exists
    if [[ -f "$cache_file" ]]; then
      cat "$cache_file"
      return 0
    fi
  fi

  local curl_args=(
    "https://music.youtube.com/youtubei/v1/${command}?prettyPrint=false"
    --compressed
    --request POST
    --header 'Accept-Encoding: gzip, deflate, br, zstd'
    --header 'Accept-Language: en-US,en;q=0.5'
    --header 'Accept: */*'
    --header 'Alt-Used: music.youtube.com'
    --header 'Connection: keep-alive'
    --header 'Content-Type: application/json'
    --header 'DNT: 1'
    --header 'Origin: https://music.youtube.com'
    --header 'Priority: u=0'
    --header 'Sec-Fetch-Dest: empty'
    --header 'Sec-Fetch-Mode: same-origin'
    --header 'Sec-Fetch-Site: same-origin'
    --header 'Sec-GPC: 1'
    --header 'TE: trailers'
    --header 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:131.0) Gecko/20100101 Firefox/131.0'
    --header 'X-Goog-AuthUser: 0'
    --header 'X-Origin: https://music.youtube.com'
    --header 'X-Youtube-Bootstrap-Logged-In: false'
    --header 'X-Youtube-Client-Name: 67'
    --header 'X-Youtube-Client-Version: 1.20241023.01.00'
    --header 'Referer: https://music.youtube.com/library'
  )

  # Prepare the data-raw argument
  local data_arg=(--data-raw "$(
    jq \
      -s \
      --compact-output \
      '.[0] * .[1]' \
      "$(dirname "${BASH_SOURCE[0]}")/data-raw.json" <(echo "$data_raw")
  )")

  # Execute curl and handle caching if enabled
  if [[ "$use_cache" == true ]]; then
    curl "${curl_args[@]}" "${data_arg[@]}" "$@" | tee "$cache_file"
  else
    curl "${curl_args[@]}" "${data_arg[@]}" "$@"
  fi
}

########
# From old artist file
#######

all_search() {
  local query=$1

  ytapi search '{
    "query": "'"$query"'",
    "context": {
      "client": {
        "originalUrl": "https://music.youtube.com/library"
      }
    }
  }' \
    --header "Referer: https://music.youtube.com/library" |
    jq \
      --compact-output \
      --from-file "$(dirname "${BASH_SOURCE[0]}")/search-all-to-all.jq"
}

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

get_all_artist_songs() {
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
