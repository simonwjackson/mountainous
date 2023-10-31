{
  herbstluftwm,
  bash,
  pkgs,
  resholve,
  stdenv,
}:
resholve.mkDerivation {
  pname = "herbstluftwm-scripts";
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
        herbstluftwm
      ];
    };
  };
}
