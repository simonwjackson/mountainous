{
  lib,
  fetchurl,
  stdenv,
  ...
}: let
  version = "0.11.0";
  releases = {
    x86_64-linux = {
      arch = "amd64";
      hash = "sha256-ypi6VuKczTcT/nv4Nf3KAK4bl83LewvF45Pn7bQInIQ=";
    };
    aarch64-linux = {
      arch = "arm64";
      hash = "sha256-G/6YBUVkFQFIj+2Txm/HZnHHKkYFKF9XRXLaxwDv3TU=";
    };
  };
  system = stdenv.hostPlatform.system;
  release = releases.${system} or (throw "gogcli does not provide a release for ${system}");
in
  stdenv.mkDerivation {
    pname = "gogcli";
    inherit version;

    src = fetchurl {
      url = "https://github.com/openclaw/gogcli/releases/download/v${version}/gogcli_${version}_linux_${release.arch}.tar.gz";
      inherit (release) hash;
    };

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      install -D -m755 gog "$out/bin/gog"
      runHook postInstall
    '';

    passthru = {
      releaseArch = release.arch;
      releaseHash = release.hash;
    };

    meta = with lib; {
      description = "Google APIs CLI tool";
      homepage = "https://github.com/openclaw/gogcli";
      license = licenses.mit;
      maintainers = [];
      platforms = builtins.attrNames releases;
      mainProgram = "gog";
    };
  }
