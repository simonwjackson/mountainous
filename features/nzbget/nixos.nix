{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) concatStringsSep mkAfter mkIf optional;

  cfg = config.mountainous.features.nzbget;
  mediaCfg = config.mountainous.features.media;

  stateDir = "/var/lib/nzbget";
  configFile = "${stateDir}/nzbget.conf";
  secretSettingsJson = builtins.toJSON cfg.secretSettings;
in {
  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = mediaCfg.enable;
        message = "mountainous.features.nzbget requires mountainous.features.media.enable = true";
      }
    ];

    services.nzbget = {
      enable = true;
      inherit (cfg) user group;

      settings =
        {
          MainDir = mediaCfg.usenetRoot;
          DestDir = mediaCfg.usenetCompletedDir;
          InterDir = mediaCfg.usenetIntermediateDir;
          NzbDir = mediaCfg.usenetIncomingDir;
          QueueDir = "${mediaCfg.usenetRoot}/queue";
          TempDir = "${mediaCfg.usenetRoot}/tmp";
          ScriptDir = "${mediaCfg.usenetRoot}/scripts";
          RequiredDir = concatStringsSep "," [
            mediaCfg.usenetCompletedDir
            mediaCfg.usenetIntermediateDir
          ];
          ControlIP = cfg.listenAddress;
          ControlPort = cfg.port;
          ControlUsername = cfg.controlUsername;
        }
        // cfg.settings;
    };

    # The upstream nzbget module runs `nzbget --quit` without --configfile,
    # which fails because NixOS doesn't place the config in any of nzbget's
    # default search paths.  Override ExecStop to pass the config explicitly.
    systemd.services.nzbget.serviceConfig.ExecStop = lib.mkForce "${pkgs.nzbget}/bin/nzbget --quit --configfile ${configFile}";

    users.users.${cfg.user}.extraGroups = optional (cfg.group != mediaCfg.group) mediaCfg.group;

    networking.firewall.allowedTCPPorts = optional cfg.openFirewall cfg.port;

    systemd.services.nzbget.preStart = mkAfter ''
      ${pkgs.python3}/bin/python <<'PY'
      import json
      from pathlib import Path

      config_file = Path(${builtins.toJSON configFile})
      secret_files = json.loads(${builtins.toJSON secretSettingsJson})

      def read_secret_value(path_str: str) -> str:
          raw = Path(path_str).read_text().strip()
          if "=" in raw:
              return raw.split("=", 1)[1].strip()
          return raw

      updates = {key: read_secret_value(path) for key, path in secret_files.items()}

      if not updates:
          raise SystemExit(0)

      lines = config_file.read_text().splitlines() if config_file.exists() else []
      seen = set()
      output = []

      for line in lines:
          if not line.startswith("#") and "=" in line:
              key = line.split("=", 1)[0]
              if key in updates:
                  output.append(f"{key}={updates[key]}")
                  seen.add(key)
                  continue
          output.append(line)

      for key, value in updates.items():
          if key not in seen:
              output.append(f"{key}={value}")

      config_file.write_text("\n".join(output) + "\n")
      PY
    '';
  };
}
