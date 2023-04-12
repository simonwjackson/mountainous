{ pkgs, ... }:

let
  downloadAlbum = pkgs.writeScriptBin "download-album" ''
    #!/usr/bin/env bash

    set -euo pipefail

    if [[ $# -ne 1 ]]; then
      echo "Usage: download-album <album_url>"
      exit 1
    fi

    album_url="$1"

    out_format="~/Music/%(album)s - %(artist)s [%(release_year)s]/%(artist)s - %(album)s - %(playlist_index)02d - %(title)s.%(ext)s"

    ${pkgs.yt-dlp}/bin/yt-dlp \
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
      --output "$out_format" \
      "$album_url"
  '';
in
{
  home.packages = [ downloadAlbum ];
}
