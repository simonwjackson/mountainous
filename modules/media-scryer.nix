# Migration commands carry their complete Python/runtime closure to the host.
{ inputs, ... }:
let
  tools =
    pkgs:
    let
      source = pkgs.runCommand "media-scryer-command-sources" { } ''
        mkdir -p "$out"
        cp ${../scripts/media-scryer-common.py} "$out/media-scryer-common.py"
        cp ${../scripts/media-scryer-provision.py} "$out/media-scryer-provision.py"
        cp ${../scripts/media-scryer-import.py} "$out/media-scryer-import.py"
        cp ${../scripts/media-scryer-parity.py} "$out/media-scryer-parity.py"
        cp ${../scripts/media-library-snapshot.py} "$out/media-library-snapshot.py"
        cp ${../scripts/media-arr-archive.py} "$out/media-arr-archive.py"
        cp ${../scripts/media-scryer-indexer-audit.py} "$out/media-scryer-indexer-audit.py"
        cp ${../scripts/media-vpn-leak-audit.py} "$out/media-vpn-leak-audit.py"
      '';
      commands = [
        "media-scryer-provision"
        "media-scryer-import"
        "media-scryer-parity"
        "media-scryer-indexer-audit"
        "media-library-snapshot"
        "media-arr-archive"
        "media-vpn-leak-audit"
      ];
      plugins = inputs.nix-extras.packages.${pkgs.stdenv.hostPlatform.system};
    in
    pkgs.buildEnv {
      name = "media-scryer-tools";
      paths = map (
        name:
        pkgs.writeShellApplication {
          inherit name;
          runtimeInputs = [
            pkgs.python3
            pkgs.zstd
          ];
          text =
            pkgs.lib.optionalString (name == "media-scryer-provision") ''
              export MEDIA_SCRYER_PLUGIN_TRANSMISSION=${plugins.scryer-plugin-transmission}/share/scryer/plugins/transmission/plugin-v3.wasm.zst
              export MEDIA_SCRYER_PLUGIN_JELLYFIN=${plugins.scryer-plugin-jellyfin}/share/scryer/plugins/jellyfin/plugin-v3.wasm.zst
            ''
            + ''
              exec python3 ${source}/${name}.py "$@"
            '';
        }
      ) commands;
    };
in
{
  nixos.modules.media-scryer =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      config =
        lib.mkIf
          (config.mountainous.features.media-applications.enable && pkgs.stdenv.hostPlatform.isx86_64)
          {
            environment.systemPackages = [ (tools pkgs) ];
          };
    };
  perSystem = { pkgs, lib, ... }: {
    packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isx86_64 {
      media-scryer-tools = tools pkgs;
      unzen-media-both =
        (inputs.self.nixosConfigurations.unzen.extendModules {
          modules = [
            ({ lib, ... }: { mountainous.features.media-applications.library = lib.mkForce "both"; })
          ];
        }).config.system.build.toplevel;
      unzen-media-scryer =
        (inputs.self.nixosConfigurations.unzen.extendModules {
          modules = [
            ({ lib, ... }: { mountainous.features.media-applications.library = lib.mkForce "scryer"; })
          ];
        }).config.system.build.toplevel;
    };
    checks = lib.optionalAttrs pkgs.stdenv.hostPlatform.isx86_64 {
      media-scryer-contract =
        let
          result = import ../tests/media-scryer-contract.nix { flake = inputs.self; };
        in
        pkgs.runCommand "media-scryer-contract" { } ''
          printf '%s\\n' '${builtins.toJSON result}' > "$out"
        '';
      media-scryer-unit = import ../tests/media-scryer-unit.nix { inherit pkgs; };
      media-scryer = import ../tests/media-scryer.nix { inherit pkgs inputs; };
    };
  };
}
