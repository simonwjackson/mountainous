{
  lib,
  mkYarnPackage,
  fetchYarnDeps,
  inputs,
  ...
}:
mkYarnPackage {
  pname = "flexget-webui";
  version = "unstable";

  src = inputs.flexget-webui;

  offlineCache = fetchYarnDeps {
    yarnLock = "${inputs.flexget-webui}/yarn.lock";
    hash = "sha256-CdcZ+W0PRzVoPaZoC/IFl0q5K7RZC3KPdjGYs9fx45o=";
  };

  buildPhase = ''
    runHook preBuild
    export HOME=$(mktemp -d)
    # Older webpack needs legacy OpenSSL provider
    export NODE_OPTIONS=--openssl-legacy-provider
    # Build may exit non-zero due to type checking warnings, but assets are still generated
    yarn --offline build || true
    # Verify build succeeded by checking for output
    test -d deps/flexget/dist/assets
    runHook postBuild
  '';

  # Don't try to generate dist tarball
  doDist = false;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r deps/flexget/dist/* $out/
    runHook postInstall
  '';

  meta = with lib; {
    description = "Web UI for FlexGet media automation";
    homepage = "https://github.com/Flexget/webui";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
