{
  lib,
  stdenv,
  makeWrapper,
  lm_sensors,
  coreutils,
  bash,
  ...
}:
stdenv.mkDerivation {
  pname = "gpd-fancontrol";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [makeWrapper];

  installPhase = ''
    mkdir -p $out/bin
    cp gpd-fancontrol.sh $out/bin/gpd-fancontrol
    chmod +x $out/bin/gpd-fancontrol

    wrapProgram $out/bin/gpd-fancontrol \
      --prefix PATH : ${lib.makeBinPath [lm_sensors coreutils bash]}
  '';

  meta = with lib; {
    description = "Dynamic fancontrol wrapper for GPD devices";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
