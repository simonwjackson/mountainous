{
  inputs,
  pkgs,
  resholve,
  system,
}: let
  inherit (inputs.self.packages.${system}) deadwax;
in
  resholve.writeScriptBin "musicull" {
    inputs = with pkgs; [
      coreutils
      curl
      deadwax
      fzf
      gnugrep
      gnused
      gum
      jq
      moreutils
      yq-go
      yt-dlp
    ];
    interpreter = "${pkgs.bash}/bin/bash";
    execer = [
      "cannot:${deadwax}/bin/deadwax"
      "cannot:${pkgs.coreutils}/bin/mkdir"
      "cannot:${pkgs.coreutils}/bin/rm"
      "cannot:${pkgs.curl}/bin/curl"
      "cannot:${pkgs.getopt}/bin/getopt"
      "cannot:${pkgs.gnugrep}/bin/grep"
      "cannot:${pkgs.fzf}/bin/fzf"
      "cannot:${pkgs.gnused}/bin/sed"
      "cannot:${pkgs.gum}/bin/gum"
      "cannot:${pkgs.jq}/bin/jq"
      "cannot:${pkgs.moreutils}/bin/sponge"
      "cannot:${pkgs.yq-go}/bin/yq"
      "cannot:${pkgs.yt-dlp}/bin/yt-dlp"
    ];
    fake = {
      external = [
        "getopt"
      ];
    };
  } (builtins.readFile ./musicull.sh)
