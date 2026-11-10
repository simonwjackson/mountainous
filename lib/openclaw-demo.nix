# Official release contains self-contained JS and the built React view.
# No npm, runtime downloads, or install scripts are needed.
{
  pkgs,
  inputs,
  node,
}:
pkgs.stdenvNoCC.mkDerivation {
  pname = "mcp-server-basic-react";
  version = "2.0.4";
  src = inputs.openclaw-basic-react-src;
  nativeBuildInputs = [ pkgs.makeWrapper ];
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/lib/demo $out/bin
    cp -r dist package.json $out/lib/demo/
    makeWrapper ${node}/bin/node $out/bin/mcp-server-basic-react \
      --add-flags $out/lib/demo/dist/index.js
  '';
  doInstallCheck = true;
  nativeInstallCheckInputs = [ pkgs.python3 ];
  installCheckPhase = ''
    python3 ${../tests/openclaw-demo.py} $out/bin/mcp-server-basic-react
  '';
  meta = {
    description = "Official read-only MCP Apps clock demo";
    license = pkgs.lib.licenses.mit;
    platforms = [ "aarch64-linux" ];
  };
}
