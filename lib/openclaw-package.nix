# nix-openclaw exposes no aarch64-linux flake package. Reuse its npm lock,
# patches and Nix-mode wrapper, with a security-fixed ARM Node runtime.
{ pkgs, inputs }:
let
  node =
    if !pkgs.stdenv.hostPlatform.isAarch64 then
      pkgs.nodejs_24
    else
      pkgs.stdenvNoCC.mkDerivation {
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
          PATH="$out/bin:$PATH" patchShebangs $out/lib/node_modules/npm/bin
        '';
        doInstallCheck = true;
        installCheckPhase = ''
          test "$($out/bin/node --version)" = v24.22.1
          $out/bin/npm --version
        '';
        passthru = {
          inherit (pkgs.nodejs_24) python;
          npm = node;
        };
        meta.platforms = [ "aarch64-linux" ];
      };
  scope = pkgs.lib.makeScope pkgs.newScope (_: {
    nodejs_24 = node;
  });
  plugins = import (inputs.nix-openclaw + "/nix/generated/openclaw-runtime-plugins");
  bundledAcpx =
    (scope.callPackage (inputs.nix-openclaw + "/nix/lib/openclaw-runtime-plugin.nix") {
      linkOpenClawPeer = false;
    })
      plugins.acpx;
  package = scope.callPackage (inputs.nix-openclaw + "/nix/packages/openclaw-gateway-npm.nix") {
    sourceInfo = import (inputs.nix-openclaw + "/nix/sources/openclaw-source.nix");
    inherit bundledAcpx;
  };
in
package.overrideAttrs (old: {
  # openclaw/openclaw#199765: remove once upstream uses access-only app reads.
  # Upstream's install script does not run postInstall. Preflight every hunk
  # before changing the installed dist; a renamed/changed bundle must fail.
  installPhase =
    old.installPhase
    + "\n"
    + ''
      ${pkgs.python3}/bin/python3 ${../tests/openclaw-app-access-only.py} "$out/lib/openclaw" --unpatched
      ${pkgs.patch}/bin/patch --batch --forward --fuzz=0 --dry-run -p1 \
        -d "$out/lib/openclaw" < ${./openclaw-app-access-only.patch}
      ${pkgs.patch}/bin/patch --batch --forward --fuzz=0 -p1 \
        -d "$out/lib/openclaw" < ${./openclaw-app-access-only.patch}
      # openclaw/openclaw#199843: fullscreen must override inline display:block.
      # Remove once a deployed release fixes it. Merged #197899 may change this
      # area. Regenerate both encodings; an upstream asset change must fail.
      ${node}/bin/node ${./openclaw-fullscreen.mjs} apply "$out/lib/openclaw"
    '';
  doInstallCheck = true;
  installCheckPhase = (old.installCheckPhase or "") + ''
    ${pkgs.python3}/bin/python3 ${../tests/openclaw-app-access-only.py} "$out/lib/openclaw"
    ${node}/bin/node ${./openclaw-fullscreen.mjs} check "$out/lib/openclaw"
  '';
  passthru = old.passthru // {
    runtimeNode = node;
  };
})
