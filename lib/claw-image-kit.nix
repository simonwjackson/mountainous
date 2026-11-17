# Exact image operations (crop, page size, enlarge, trace, compare, PDF) as a
# local stdio MCP server inside each OpenClaw container. It runs there, not on
# the front door, because its inputs are files in the gateway's own media and
# workspace folders, which no other host can read. Agents still get only these
# named tools; the gateway keeps denying group:runtime.
{ pkgs }:
let
  src = ../packages/claw-image-kit;
  tools = [
    pkgs.imagemagick
    pkgs.resvg
    pkgs.potrace
  ];
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "claw-image-kit";
  version = "1";
  inherit src;
  nativeBuildInputs = [ pkgs.makeWrapper ];
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/lib/claw-image-kit $out/bin
    cp image_kit.py server.py $out/lib/claw-image-kit/
    makeWrapper ${pkgs.python3}/bin/python3 $out/bin/claw-image-kit \
      --add-flags $out/lib/claw-image-kit/server.py \
      --set PATH ${pkgs.lib.makeBinPath tools}
  '';
  doInstallCheck = true;
  nativeInstallCheckInputs = [ pkgs.python3 ] ++ tools;
  installCheckPhase = ''
    cp ${src}/test_image_kit.py $out/lib/claw-image-kit/
    (cd $out/lib/claw-image-kit && python3 -m unittest -v test_image_kit)
    rm -r $out/lib/claw-image-kit/test_image_kit.py $out/lib/claw-image-kit/__pycache__
  '';
  passthru.toolNames = [
    "image_info"
    "fit_page"
    "crop"
    "split"
    "enlarge"
    "make_transparent"
    "vectorize"
    "render_svg"
    "compare"
    "pdf"
  ];
  meta.description = "Exact image operations for OpenClaw agents over MCP stdio";
}
