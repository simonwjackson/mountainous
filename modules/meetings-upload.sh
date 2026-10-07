# Upload every finished .vtt in the downloads folder to the meetings store.
#
# Environment:
#   MEETINGS_URL        base URL, for example https://meetings.example.ts.net
#   MEETINGS_DOWNLOADS  folder to scan (default: $HOME/Downloads)
#
# 201 created and 200 duplicate: the store has it, so the file is deleted.
# 422 not a transcript: renamed to NAME.vtt.rejected and not tried again.
# Anything else: the file stays and the next run tries again. Exit status 1.

: "${MEETINGS_URL:?MEETINGS_URL is not set}"
downloads="${MEETINGS_DOWNLOADS:-$HOME/Downloads}"
response="$(mktemp)"
trap 'rm -f "$response"' EXIT

failed=0
shopt -s nullglob
for file in "$downloads"/*.vtt; do
  [ -f "$file" ] || continue
  name="$(basename "$file")"
  if ! status="$(curl --silent --show-error --max-time 120 \
    --output "$response" --write-out '%{http_code}' \
    --header 'Content-Type: text/vtt' \
    --data-binary "@$file" \
    --url-query "name=$name" \
    "$MEETINGS_URL/v1/transcripts")"; then
    echo "not sent, will retry: $name"
    failed=1
    continue
  fi
  case "$status" in
    200 | 201)
      rm -f -- "$file"
      echo "$status $name: $(cat "$response")"
      ;;
    422)
      mv -f -- "$file" "$file.rejected"
      echo "rejected, renamed to $name.rejected: $(cat "$response")"
      ;;
    *)
      echo "HTTP $status, will retry: $name: $(cat "$response")"
      failed=1
      ;;
  esac
done
exit "$failed"
