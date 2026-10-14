{
  config,
  self,
  inputs,
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
      contract = import ../tests/app-profiles.nix {
        inherit lib;
        hosts = lib.genAttrs (lib.attrNames config.nixos.hosts) (name: self.nixosConfigurations.${name});
        deploy = self.deploy;
        unzen = self.nixosConfigurations.unzen.config;
      };
      settingsFile =
        (builtins.head (
          builtins.filter (
            mount: mount.where == "/var/lib/pi/simon/agent/settings.json"
          ) self.nixosConfigurations.unzen.config.systemd.mounts
        )).what;
    in
    {
      checks.app-profiles =
        assert contract.status == "pass";
        pkgs.runCommand "app-profiles-contract" { nativeBuildInputs = [ pkgs.python3 ]; } ''
          python3 ${../.}/tests/test_app_update.py
          # The shipped wrapper, not a copied shell fragment, owns isolation.
          grep -F 'mktemp -d "$PI_CODING_AGENT_DIR/tmp/run.XXXXXXXXXX"' ${self.packages.${system}.app-pi}/bin/pi
          grep -F 'export PI_CODING_AGENT_DIR=' ${self.packages.${system}.app-pi}/bin/pi
          grep -F 'settings read-only bind mount is not ready' ${self.packages.${system}.app-pi}/bin/pi
          python3 -c 'import json; s=json.load(open("${settingsFile}")); assert s["enableInstallTelemetry"] is False; assert s["defaultProvider"] == "cliproxyapi"; assert s["defaultModel"] == "gpt-5.6-sol"; assert "lastChangelogVersion" not in s; assert "packages" not in s'
          grep -F 'export PI_OFFLINE=1' ${self.packages.${system}.app-pi}/bin/pi
          touch $out
        '';
    };
}
