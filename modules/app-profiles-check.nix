{
  config,
  inputs,
  self,
  ...
}:
{
  perSystem =
    {
      pkgs,
      system,
      lib,
      ...
    }:
    let
      enrolledHosts = lib.mapAttrs (name: _: self.nixosConfigurations.${name}) config.nixos.enrolledHosts;
      preEnrollment = lib.genAttrs [ "asama" "asama-vm" ] (name: self.nixosConfigurations.${name}.config);
      contract = import ../tests/app-profiles.nix {
        inherit lib preEnrollment;
        hosts = enrolledHosts;
        deploy = self.deploy;
        unzen = self.nixosConfigurations.unzen.config;
      };
      sync = import ../tests/fleet-sync.nix {
        inherit lib preEnrollment;
        external = import ../tests/fleet-sync-external.nix { inherit inputs lib; };
        hosts = lib.mapAttrs (_: h: h.config) enrolledHosts;
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
      checks.app-updater-closure =
        pkgs.runCommand "app-updater-closure"
          {
            nativeBuildInputs = [ pkgs.python3 ];
            passAsFile = [ "startup" ];
            startup =
              self.nixosConfigurations.unzen.config.systemd.services.app-update-pi.serviceConfig.ExecStart;
          }
          ''
            python3 ${../tests/app-updater-closure.py} "$startupPath"
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
