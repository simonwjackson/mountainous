# Official 0.11.0 release, supplied as a locked non-flake input.
{
  lib,
  stdenv,
  src,
}:
stdenv.mkDerivation {
  pname = "gogcli";
  version = "0.11.0";
  inherit src;
  sourceRoot = ".";
  unpackPhase = ''tar -xzf "$src"'';
  installPhase = ''install -D -m755 gog "$out/bin/gog"'';
  doInstallCheck = true;
  installCheckPhase = ''"$out/bin/gog" --version | grep '^v0.11.0 ' '';
  meta = {
    description = "Google APIs CLI, pinned for the assistant Google service";
    homepage = "https://github.com/openclaw/gogcli";
    license = lib.licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "gog";
  };
}
