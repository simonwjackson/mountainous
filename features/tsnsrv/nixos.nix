{
  config,
  lib,
  ...
}: let
  inherit (lib) mapAttrs' mkIf nameValuePair;
  cfg = config.mountainous.features.tsnsrv;
in {
  config = mkIf cfg.enable {
    users.groups.tsnsrv = {};
    users.users.tsnsrv = {
      isSystemUser = true;
      group = "tsnsrv";
    };

    systemd.services = mapAttrs' (name: svcCfg: let
      effectiveAuthKeyFile =
        if svcCfg.authKeyFile != null
        then svcCfg.authKeyFile
        else cfg.authKeyFile;
    in
      nameValuePair "tsnsrv-${name}" {
        description = "tsnsrv Tailscale proxy for ${name}";
        after = ["network-online.target"];
        wants = ["network-online.target"];
        wantedBy = ["multi-user.target"];
        environment.HOME = "/var/lib/tsnsrv-${name}";
        serviceConfig = {
          Type = "simple";
          User = "tsnsrv";
          Group = "tsnsrv";
          StateDirectory = "tsnsrv-${name}";
          Restart = "on-failure";
          RestartSec = 5;
        };
        script = ''
          export TS_AUTHKEY="$(cat ${effectiveAuthKeyFile})"
          exec ${cfg.package}/bin/tsnsrv -name ${name} -stateDir /var/lib/tsnsrv-${name} ${svcCfg.backendUrl}
        '';
      })
    cfg.services;
  };
}
