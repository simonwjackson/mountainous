{
  lib,
  resholve,
  pkgs,
}:
resholve.writeScriptBin "youtube-playlist-sync" {
  inputs = with pkgs; [
    bash
    beets
    chromaprint
    coreutils
    curl
    expect
    ffmpeg
    findutils
    gnugrep
    gnused
    gum
    jq
    tone
    yt-dlp
  ];
  interpreter = "${pkgs.bash}/bin/bash";
  execer = [
    "cannot:${pkgs.bash}/bin/bash"
    "cannot:${pkgs.coreutils}/bin/mkdir"
    "cannot:${pkgs.coreutils}/bin/rm"
    "cannot:${pkgs.coreutils}/bin/mktemp"
    "cannot:${pkgs.coreutils}/bin/trap"
    "cannot:${pkgs.curl}/bin/curl"
    "cannot:${pkgs.findutils}/bin/find"
    "cannot:${pkgs.ffmpeg}/bin/ffmpeg"
    "cannot:${pkgs.gnused}/bin/sed"
    "cannot:${pkgs.gnugrep}/bin/grep"
    "cannot:${pkgs.gum}/bin/gum"
    "cannot:${pkgs.jq}/bin/jq"
    "cannot:${pkgs.yt-dlp}/bin/yt-dlp"
    "cannot:${pkgs.beets}/bin/beet"
    "cannot:${pkgs.expect}/bin/expect"
    "cannot:${pkgs.tone}/bin/tone"
    "cannot:${pkgs.chromaprint}/bin/fpcalc"
  ];
  keep = {
  };
  fake = {
    external = [
    ];
  };
} (builtins.readFile ./youtube-playlist-sync.sh)
