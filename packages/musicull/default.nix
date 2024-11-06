{
  lib,
  resholve,
  pkgs,
}:
resholve.writeScriptBin "musicull" {
  inputs = with pkgs; [
    coreutils
    curl
    gnugrep
    gnused
    gum
    jq
    yq-go
    yt-dlp
  ];
  interpreter = "${pkgs.bash}/bin/bash";
  execer = [
    "cannot:${pkgs.coreutils}/bin/mkdir"
    "cannot:${pkgs.coreutils}/bin/rm"
    "cannot:${pkgs.curl}/bin/curl"
    "cannot:${pkgs.getopt}/bin/getopt"
    "cannot:${pkgs.gnugrep}/bin/grep"
    "cannot:${pkgs.gnused}/bin/sed"
    "cannot:${pkgs.gum}/bin/gum"
    "cannot:${pkgs.jq}/bin/jq"
    "cannot:${pkgs.yq-go}/bin/yq"
    "cannot:${pkgs.yt-dlp}/bin/yt-dlp"
  ];
  fake = {
    external = [
      "getopt"
      "musicull"
    ];
  };
} (builtins.readFile ./deadwax.sh)
