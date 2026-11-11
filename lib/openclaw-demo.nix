# Official release contains self-contained JS and the built React view.
# No npm, runtime downloads, or install scripts are needed.
{
  pkgs,
  inputs,
  node,
  name ? "basic-react",
  tool ? "get-time",
}:
pkgs.stdenvNoCC.mkDerivation {
  pname = "mcp-server-${name}";
  version = "2.0.4";
  src = inputs."openclaw-${name}-src";
  nativeBuildInputs = [ pkgs.makeWrapper ];
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/lib/demo $out/bin
    cp -r dist package.json $out/lib/demo/
    makeWrapper ${node}/bin/node $out/bin/mcp-server-${name} \
      --add-flags $out/lib/demo/dist/index.js
  '';
  doInstallCheck = true;
  nativeInstallCheckInputs = [ pkgs.python3 ];
  installCheckPhase = ''
    python3 ${../tests/openclaw-demo.py} $out/bin/mcp-server-${name} ${tool}
  '';
  meta = {
    description = "Official MCP Apps ${name} demo";
    license = pkgs.lib.licenses.mit;
    platforms = [ "aarch64-linux" ];
  };
}
