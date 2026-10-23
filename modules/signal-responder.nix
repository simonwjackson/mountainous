# Signals: alerts on the notify topic become read-only triage by an assistant.
#
# Sources keep publishing to ntfy as they do today (beszel-notify,
# storage-alert). signal-responder follows the topic with a read-write ntfy
# token. A message from an agent sender (`notify send --name`) that matches a
# rule becomes a signal. The gate holds it (a clear during the hold means it
# recovered), allows one run per alert per cool-down, and caps runs per source
# and in total per 24 hours. A signal that passes becomes a one-time schedule
# on the person's assistant, on the background lane. When the run ends, its
# final answer goes back to the topic as "Triage: <title>".
#
# Adding a source touches no code: a sender that uses `notify send`, a rule
# below, and a playbook in modules/signal-playbooks/. See
# packages/signal-responder for the gate's rules and tests.
#
# Known limit: the service reaches the assistant through its unauthenticated
# loopback RPC, as every local client does today. Alerts about rakku itself
# cannot be triaged here: the hub, the model gateway and the assistant all run
# on rakku.
{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.signal-responder = pkgs.rustPlatform.buildRustPackage {
        pname = "signal-responder";
        version = "0.1.0";
        src = ../packages/signal-responder;
        cargoLock.lockFile = ../packages/signal-responder/Cargo.lock;
        meta.mainProgram = "signal-responder";
      };
      # The package build runs the crate's unit tests.
      checks.signal-responder = self.packages.${pkgs.stdenv.hostPlatform.system}.signal-responder;
    };

  nixos.modules.signal-responder =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.mountainous.features.signal-responder;
      system = pkgs.stdenv.hostPlatform.system;
      package = self.packages.${system}.signal-responder;
      notify = self.packages.${system}.notify-sync;
      assistant = config.mountainous.features.pi-assistant.people.${cfg.person};
      stateDir = "/var/lib/signal-responder";
      playbook = name: builtins.readFile (./signal-playbooks + "/${name}.md");

      rule = lib.types.submodule {
        options = {
          source = lib.mkOption {
            type = lib.types.str;
            description = "The signal's source name, used in keys, limits and logs.";
          };
          sender = lib.mkOption {
            type = lib.types.str;
            description = "Regex for the sender's `notify send --name`.";
          };
          fire = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Regexes for titles that mean something is wrong.";
          };
          ignore = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Regexes for titles that never fire, checked after `fire`.";
          };
          holdSeconds = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 600;
            description = "How long a signal waits for its own recovery.";
          };
          cooldownSeconds = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 6 * 3600;
            description = "The least time between two triages of the same alert.";
          };
          dailyLimit = lib.mkOption {
            type = lib.types.ints.positive;
            default = 5;
            description = "Triages from this source in any 24 hours.";
          };
          tokenBudget = lib.mkOption {
            type = lib.types.ints.positive;
            default = 1000000;
            description = "The token budget of each triage's schedule.";
          };
          playbook = lib.mkOption {
            type = lib.types.lines;
            description = "What the assistant looks at for this source.";
          };
        };
      };

      configFile = pkgs.writeText "signal-responder.json" (
        builtins.toJSON {
          ntfyUrl = "http://${config.services.ntfy-sh.settings.listen-http}";
          topic = "notify";
          rpcUrl = "http://127.0.0.1:${toString assistant.webPort}/rpc";
          owner = cfg.person;
          inherit (cfg) lane dailyLimit rules;
          notify = "${notify}/bin/notify";
          notifyName = "first-responder";
          inherit stateDir;
        }
      );
    in
    {
      options.mountainous.features.signal-responder = {
        enable = lib.mkEnableOption "triage of notify alerts by an assistant";
        person = lib.mkOption {
          type = lib.types.str;
          example = "simon";
          description = "Whose assistant triages. It must be in pi-assistant.people.";
        };
        lane = lib.mkOption {
          type = lib.types.enum [
            "background"
            "mechanical"
            "creative"
          ];
          default = "background";
        };
        dailyLimit = lib.mkOption {
          type = lib.types.ints.positive;
          default = 8;
          description = "Triages from all sources in any 24 hours.";
        };
        rules = lib.mkOption {
          type = lib.types.listOf rule;
          description = "Which alerts become signals. The first matching rule wins.";
          default = [
            {
              source = "beszel";
              sender = "^beszel$";
              # Titles from beszel 0.20.0 internal/alerts. "above threshold" is a
              # recovery for the low alerts (battery), so those are ignored.
              fire = [
                "^Connection to \\S+ is down"
                " above threshold$"
                "^\\S+ battery below threshold$"
                "^Failed services on "
                "^Unhealthy container "
                "^\\d+ unhealthy containers on "
                "^SMART (failure|warning) on "
                "^Network monitor loss on "
              ];
              ignore = [ " battery above threshold$" ];
              playbook = playbook "beszel-tool" + "\n" + playbook "beszel";
            }
            {
              source = "storage";
              sender = "^[a-z0-9-]+$";
              fire = [ "^\\S+: storage (problem|check unavailable)$" ];
              playbook = playbook "beszel-tool" + "\n" + playbook "storage";
            }
          ];
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.mountainous.features.pi-assistant.people ? ${cfg.person};
            message = "signal-responder.person ${cfg.person} has no assistant in pi-assistant.people.";
          }
          {
            assertion = config.mountainous.features.notify-server.enable;
            message = "signal-responder follows the ntfy server on the same host.";
          }
        ];

        sops.secrets.signal-responder-token = {
          sopsFile = ../secrets/notify/server.yaml;
          mode = "0400";
          restartUnits = [ "signal-responder.service" ];
        };

        # The playbooks read Beszel through the assistant's own credential.
        mountainous.features.pi-assistant.people.${cfg.person}.credentials.beszel-mcp-token =
          config.sops.secrets.beszel-mcp-token.path;

        users.groups.signal-responder = { };
        users.users.signal-responder = {
          isSystemUser = true;
          group = "signal-responder";
        };
        systemd.services.signal-responder = {
          description = "Triage notify alerts with ${cfg.person}'s assistant";
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          after = [
            "network-online.target"
            "ntfy-sh.service"
            "pi-assistant-${cfg.person}.service"
          ];
          unitConfig.RequiresMountsFor = [ stateDir ];
          environment = {
            NOTIFY_URL = config.mountainous.notifications.server;
            NOTIFY_TOKEN_FILE = "%d/ntfy-token";
            NOTIFY_BUTTON_TOKEN_FILE = "%d/button";
          };
          serviceConfig = {
            ExecStart = "${lib.getExe package} --config ${configFile}";
            LoadCredential = [
              "ntfy-token:${config.sops.secrets.signal-responder-token.path}"
              "button:${config.sops.secrets.notify-button-token.path}"
            ];
            User = "signal-responder";
            Group = "signal-responder";
            StateDirectory = "signal-responder";
            StateDirectoryMode = "0700";
            Restart = "always";
            RestartSec = "10s";
            NoNewPrivileges = true;
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectHome = true;
            ProtectSystem = "strict";
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            RestrictSUIDSGID = true;
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
              "AF_UNIX"
            ];
            UMask = "0077";
          };
        };
        environment.persistence."/tundra/permafrost".directories = [
          {
            directory = stateDir;
            user = "signal-responder";
            group = "signal-responder";
            mode = "0700";
          }
        ];
      };
    };
}
