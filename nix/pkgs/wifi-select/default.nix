{
  bash,
  coreutils-full,
  fzf,
  gawk,
  gnugrep,
  gnused,
  networkmanager,
  pkgs,
  resholve,
  stdenv,
}:
resholve.mkDerivation {
  pname = "wifi-select";
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
      interpreter = "${bash}/bin/bash";
      inputs = [
        coreutils-full
        fzf
        gawk
        gnugrep
        networkmanager
        gnused
      ];
      fake = {
        external = [
          # Make sure we can self reference our scripts
        ];
      };
      execer = [
        # resholve cannot verify args from these apps
        "cannot:${fzf}/bin/fzf"
        "cannot:${networkmanager}/bin/nmcli"
      ];
    };
  };
}
