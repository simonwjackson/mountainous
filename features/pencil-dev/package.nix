{
  lib,
  appimageTools,
  fetchurl,
  stdenv,
}:
let
  pname = "pencil-dev";
  version = "1.1.48";

  src = {
    x86_64-linux = fetchurl {
      url = "https://www.pencil.dev/download/Pencil-linux-x86_64.AppImage";
      hash = "sha256-4ePRXqFVIa9g7idyiX7WZmnBHxewxlXh9i21GQN5/LY=";
    };

    aarch64-linux = fetchurl {
      url = "https://www.pencil.dev/download/Pencil-linux-arm64.AppImage";
      hash = "sha256-ODhKW2XgCHZIorfuHKyF7brgaWSFg8fr2UYb5ZPjSnA=";
    };
  }.${stdenv.hostPlatform.system};

  extracted = appimageTools.extractType2 {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    mv "$out/bin/${pname}" "$out/bin/.${pname}-wrapped"
    printf '%s\n' \
      '#!/usr/bin/env bash' \
      'exec "'$out'/bin/.${pname}-wrapped" --no-sandbox "$@"' \
      > "$out/bin/${pname}"
    chmod +x "$out/bin/${pname}"

    install -Dm444 ${extracted}/pencil.desktop "$out/share/applications/${pname}.desktop"
    substituteInPlace "$out/share/applications/${pname}.desktop" \
      --replace-fail 'Exec=AppRun --no-sandbox %U' "Exec=$out/bin/${pname} %U"

    install -Dm444 ${extracted}/pencil.png \
      "$out/share/icons/hicolor/512x512/apps/pencil.png"
  '';

  meta = with lib; {
    description = "Pencil desktop app from pencil.dev";
    homepage = "https://pencil.dev";
    license = licenses.unfree;
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
    mainProgram = pname;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
  };
}
