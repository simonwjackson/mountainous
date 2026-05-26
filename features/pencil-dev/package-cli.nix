{
  lib,
  buildNpmPackage,
  fetchurl,
}:
buildNpmPackage rec {
  pname = "pencil-cli";
  version = "0.2.4";

  src = fetchurl {
    url = "https://registry.npmjs.org/@pencil.dev/cli/-/cli-0.2.4.tgz";
    hash = "sha256-zDd8akMt1aits+8/Ds9ifgF3fbVEl457bp/N+CIxqOc=";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-v2zzQgOugPMWbbD/EY2dRZjSoksHdrKGnngtJjuQbeg=";

  dontNpmBuild = true;

  meta = with lib; {
    description = "Pencil CLI from pencil.dev";
    homepage = "https://pencil.dev";
    license = licenses.unfree;
    sourceProvenance = [sourceTypes.binaryBytecode sourceTypes.binaryNativeCode];
    mainProgram = "pencil";
    platforms = platforms.linux;
  };
}
