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
          quickshellUnit = desktop.systemd.user.units."quickshell.service".text;
          restartIfChanged = unit.restartIfChanged;
          reloadIfChanged = unit.reloadIfChanged;
          restartTriggers = unit.restartTriggers;
          hjemReloadRequires = desktop.systemd.services."hjem-reload@".requires;
          hjemReloadAfter = desktop.systemd.services."hjem-reload@".after;
          hjemReloadPost = desktop.systemd.services."hjem-reload@".serviceConfig.ExecStartPost;
        }
      );
    in
    {
      checks.desktop-safety =
        assert unit.restartIfChanged == false;
        assert unit.reloadIfChanged == false;
        assert unit.restartTriggers == [ ];
        assert lib.hasInfix "X-RestartIfChanged=false" desktop.systemd.user.units."quickshell.service".text;
        assert builtins.elem "hjem-activate@%i.service" desktop.systemd.services."hjem-reload@".after;
        assert builtins.elem "hjem-activate@%i.service" desktop.systemd.services."hjem-reload@".requires;
        assert builtins.length desktop.systemd.services."hjem-reload@".serviceConfig.ExecStartPost == 1;
        assert lib.hasInfix "quickshell-after-hjem" (
          builtins.head desktop.systemd.services."hjem-reload@".serviceConfig.ExecStartPost
        );
        assert builtins.elem "sysinit-reactivation.target" desktop.systemd.targets.hjem.wantedBy;
        assert builtins.elem "hjem-reload@simon.service" desktop.systemd.targets.hjem.requires;
        assert unit.serviceConfig.KillMode == "mixed";
        assert unit.serviceConfig.WatchdogSec == "20s";
        assert unit.serviceConfig.WatchdogSignal == "SIGKILL";
        assert unit.serviceConfig.NotifyAccess == "all";
        assert desktop.system.configurationRevision == (self.rev or self.dirtyRev or null);
        pkgs.runCommand "desktop-safety"
          {
            nativeBuildInputs = [
              pkgs.python3
              pkgs.nodejs
              pkgs.quickshell
              pkgs.labwc
            ];
            QUICKSHELL = "${pkgs.quickshell}/bin/qs";
            LABWC = "${pkgs.labwc}/bin/labwc";
          }
          ''
            printf 'Evaluated Myoko settings: %s\n' ${lib.escapeShellArg evidence}
            printf '%s\n' ${lib.escapeShellArg evidence} > evaluated.json
            python3 ${../tests/quickshell-switch.py} evaluated.json ${../scripts/quickshell-after-hjem}
            node ${./quickshell/launcher-model.test.js} ${./quickshell/launcher-model.js} ${./quickshell}
            node ${./quickshell/desktop-safety.test.js} ${./quickshell}
            printf '%s\n' ${lib.escapeShellArg evidence} > $out
          '';
    };
}
