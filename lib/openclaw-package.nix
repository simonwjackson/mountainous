# nix-openclaw exposes no aarch64-linux flake package. Reuse its npm lock,
# patches and Nix-mode wrapper, with a security-fixed ARM Node runtime.
{ pkgs, inputs }:
let
  node = pkgs.stdenvNoCC.mkDerivation {
    pname = "nodejs-openclaw";
    version = "24.22.1";
    src = inputs.openclaw-node-arm64;
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];
    patchelfFlags = [ "--no-sort" ];
    dontBuild = true;
    dontStrip = true;
    installPhase = ''
      mkdir -p $out
      cp -r bin include lib share $out/
      patchShebangs $out/bin
    '';
    passthru = {
      inherit (pkgs.nodejs_24) python;
      npm = node;
    };
    meta.platforms = [ "aarch64-linux" ];
  };
  scope = pkgs.lib.makeScope pkgs.newScope (_: { nodejs_24 = node; });
  plugins = import (inputs.nix-openclaw + "/nix/generated/openclaw-runtime-plugins");
  bundledAcpx = (scope.callPackage (inputs.nix-openclaw + "/nix/lib/openclaw-runtime-plugin.nix") {
    linkOpenClawPeer = false;
  }) plugins.acpx;
in
scope.callPackage (inputs.nix-openclaw + "/nix/packages/openclaw-gateway-npm.nix") {
  sourceInfo = import (inputs.nix-openclaw + "/nix/sources/openclaw-source.nix");
  inherit bundledAcpx;
}
