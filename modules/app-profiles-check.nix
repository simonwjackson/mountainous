{ config, self, ... }:
{
  perSystem =
    {
      pkgs,
      system,
      lib,
      ...
    }:
    let
      contract = import ../tests/app-profiles.nix {
        inherit lib;
        hosts = lib.genAttrs (lib.attrNames config.nixos.hosts) (name: self.nixosConfigurations.${name});
        deploy = self.deploy;
        unzen = self.nixosConfigurations.unzen.config;
      };
      sync = import ../tests/fleet-sync.nix {
        inherit lib;
        hosts = lib.genAttrs (lib.attrNames config.nixos.hosts) (
          name: self.nixosConfigurations.${name}.config
        );
      };
    in
    {
      checks.app-profiles =
        assert contract.status == "pass";
        pkgs.runCommand "app-profiles-contract" { nativeBuildInputs = [ pkgs.python3 ]; } ''
          python3 ${../.}/tests/test_app_update.py
          grep -F 'mktemp -d "$agent_dir/tmp/run.XXXXXXXXXX"' ${self.packages.${system}.app-pi}/bin/pi
          grep -F 'export PI_OFFLINE=1' ${self.packages.${system}.app-pi}/bin/pi
          touch $out
        '';
      checks.fleet-sync =
        assert sync;
        pkgs.runCommand "fleet-sync-contract"
          {
            nativeBuildInputs = [ pkgs.python3 ];
            passAsFile = [ "startup" ];
            startup = builtins.toJSON self.nixosConfigurations.tate.config.systemd.services.syncthing.serviceConfig.ExecStartPre;
          }
          ''
            python3 ${../tests/fleet-sync-startup.py} "$startupPath"
            touch $out
          '';
    };
}
