{
  lib,
  stdenvNoCC,
  inputs,
  ...
}:
stdenvNoCC.mkDerivation {
  pname = "flexget-webui";
  version = "2.0.29";

  src = inputs.flexget-webui;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r $src/* $out/
    runHook postInstall
  '';

  meta = with lib; {
    description = "Web UI for FlexGet media automation";
    homepage = "https://github.com/Flexget/webui";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
