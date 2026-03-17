{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) concatStringsSep mkAfter mkEnableOption mkIf mkOption optional types;

  cfg = config.mountainous.nzbget;
  mediaCfg = config.mountainous.features.media;

  stateDir = "/var/lib/nzbget";
  configFile = "${stateDir}/nzbget.conf";
  secretSettingsJson = builtins.toJSON cfg.secretSettings;
in {
  options.mountainous.nzbget = {
    enable = mkEnableOption "NZBGet with shared media defaults";

    user = mkOption {
      type = types.str;
      default = "nzbget";
      description = "User account under which NZBGet runs.";
    };

    group = mkOption {
      type = types.str;
      default = "media";
      description = "Primary group for NZBGet; usually the shared media group.";
    };

    listenAddress = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Bind address for the NZBGet UI and RPC interface.";
    };

    port = mkOption {
      type = types.port;
      default = 6789;
      description = "NZBGet control port.";
    };

    controlUsername = mkOption {
      type = types.str;
      default = "nzbget";
      description = "Username for the NZBGet web UI and RPC interface.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the NZBGet port in the firewall.";
    };

    settings = mkOption {
      type = types.attrsOf (types.oneOf [types.bool types.int types.str]);
      default = {};
      description = "Non-secret NZBGet settings forwarded to services.nzbget.settings.";
      example = {
        "Server1.Name" = "primary";
        "Server1.Host" = "news.example.com";
        "Server1.Port" = 563;
        "Server1.Encryption" = true;
        "Server1.Connections" = 20;
        "Server1.Username" = "my-user";
      };
    };

    secretSettings = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = ''
        Secret-backed NZBGet settings, mapping config key to a runtime file path.

        These values are patched into ${configFile} during service startup so they
        do not end up in the Nix store.
      '';
      example = {
        ControlPassword = "/run/agenix/nzbget-control-password";
        "Server1.Password" = "/run/agenix/usenet-primary-password";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = mediaCfg.enable;
        message = "mountainous.nzbget requires mountainous.features.media.enable = true";
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
