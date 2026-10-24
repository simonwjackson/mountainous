# The flake-parts self is captured here; no extra NixOS specialArgs are needed.
{ self, ... }:
{
  nixos.modules.desktop =
    { lib, ... }:
    {
      system.configurationRevision = lib.mkDefault (self.rev or self.dirtyRev or null);
    };

  perSystem =
    { pkgs, lib, ... }:
    let
      desktop = self.nixosConfigurations.myoko.config;
      unit = desktop.systemd.user.services.quickshell;
      evidence = builtins.unsafeDiscardStringContext (
        builtins.toJSON {
          toplevelDrvPath = desktop.system.build.toplevel.drvPath;
          configurationRevision = desktop.system.configurationRevision;
          quickshell = unit.serviceConfig;
          hjemReloadAfter = desktop.systemd.services."hjem-reload@".after;
          hjemReloadPost = desktop.systemd.services."hjem-reload@".serviceConfig.ExecStartPost;
        }
      );
    in
    {
      checks.desktop-safety =
        assert unit.serviceConfig.KillMode == "mixed";
        assert unit.serviceConfig.WatchdogSec == "20s";
        assert unit.serviceConfig.WatchdogSignal == "SIGKILL";
        assert unit.serviceConfig.NotifyAccess == "all";
        assert desktop.system.configurationRevision == (self.rev or self.dirtyRev or null);
        pkgs.runCommand "desktop-safety"
          {
            nativeBuildInputs = [
              pkgs.nodejs
              pkgs.quickshell
              pkgs.labwc
            ];
            QUICKSHELL = "${pkgs.quickshell}/bin/qs";
            LABWC = "${pkgs.labwc}/bin/labwc";
          }
          ''
            printf 'Evaluated Myoko settings: %s\n' ${lib.escapeShellArg evidence}
            node ${./quickshell/launcher-model.test.js} ${./quickshell/launcher-model.js} ${./quickshell}
            node ${./quickshell/desktop-safety.test.js} ${./quickshell}
            printf '%s\n' ${lib.escapeShellArg evidence} > $out
          '';
    };
}
