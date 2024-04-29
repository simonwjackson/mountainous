{
  # coreutils-full,
  # fzf,
  # gawk,
  # gnugrep,
  # gnused,
  # networkmanager,
  pkgs,
  resholve,
  stdenv,
}:
resholve.mkDerivation {
  pname = "popup-term";
  version = "unstable";
  src = ./src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    find $src -type f -exec bash -c 'file="$1"; install -Dm 755 "$file" "$out/''${file#$src/}"' -- {} \;

    runHook postInstall
  '';

  solutions = {
    default = {
      scripts = [
        "bin/*"
      ];
      interpreter = "${pkgs.bash}/bin/bash";
      inputs = with pkgs; [
        # coreutils-full
        # fzf
        # gawk
        # gnugrep
        # networkmanager
        # gnused

        xdotool
        coreutils
        kitty
      ];
      fake = {
        external = [
          # Make sure we can self reference our scripts
        ];
      };
      execer = with pkgs; [
        # resholve cannot verify args from these apps
        "cannot:${xdotool}/bin/xdotool"
        "cannot:${kitty}/bin/kitty"
        # "cannot:${networkmanager}/bin/nmcli"
      ];
    };
  };
}
