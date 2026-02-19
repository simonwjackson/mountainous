{
  lib,
  stdenv,
  fetchzip,
  autoPatchelfHook,
  alsa-lib,
  openssl,
}:
stdenv.mkDerivation rec {
  pname = "airconnect";
  version = "1.9.2";

  src = fetchzip {
    url = "https://github.com/philippe44/AirConnect/releases/download/${version}/AirConnect-${version}.zip";
    sha256 = "sha256-/RiymBhYNxj3jEiq5hguMGe6j55LcnFxwnmsuMQ/wHg=";
    stripRoot = false;
  };

  nativeBuildInputs = [autoPatchelfHook];
  buildInputs = [alsa-lib openssl];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp airupnp-linux-x86_64-static $out/bin/airupnp
    chmod +x $out/bin/airupnp

    runHook postInstall
  '';

  meta = with lib; {
    description = "Use AirPlay to stream to UPnP/Sonos & Chromecast devices";
    homepage = "https://github.com/philippe44/AirConnect";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [];
  };
}
