VINYL_VAULT_DOWNLOAD_DIR=${VINYL_VAULT_DOWNLOAD_DIR:-$(pwd)}
VINYL_VAULT_OUTPUT_TEMPLATE=${VINYL_VAULT_OUTPUT_TEMPLATE:-"$VINYL_VAULT_DOWNLOAD_DIR/%(album)s - %(artist)s [%(release_year)s]/%(artist)s - %(album)s - %(playlist_index)02d - %(title)s.%(ext)s"}

if [[ $# -lt 1 ]]; then
  echo "Usage: vinyl-vault <album_url> [additional_args]"
  exit 1
fi

album_url="$1"
shift

mkdir -p "$VINYL_VAULT_DOWNLOAD_DIR"

yt-dlp \
  --no-continue \
  --yes-playlist \
  --write-thumbnail \
  --write-all-thumbnails \
  --write-description \
  --write-info-json \
  --add-metadata \
  --extract-audio \
  --audio-format "best" \
  --audio-quality 0 \
  --embed-thumbnail \
  --add-metadata \
  --output "$VINYL_VAULT_OUTPUT_TEMPLATE" \
  "$@" \
  "$album_url"
