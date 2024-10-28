ytapi() {
  local command=$1
  local data_raw=$2
  shift 2

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

  # Execute curl with base arguments, data argument, and any additional arguments
  curl "${curl_args[@]}" "${data_arg[@]}" "$@"
}
