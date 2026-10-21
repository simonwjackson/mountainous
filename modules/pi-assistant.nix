# A household's personal assistants: one Pi assistant per person, each as its
# own Unix user with its own conversations, memory, and files, a shared
# Household assistant, and one tailnet name in front of them all:
# https://assistant.<tailnet>.
#
# The operating system keeps the people apart, not a prompt. Every instance
# runs as its own user and its state directory is 0700, so one person's
# assistant cannot read the other's conversations, memory, or files. The
# Household instance never reads a personal one either. The only shared path
# is the notebook directory, 2770 for the `household` group, which every
# instance writes and only a person's own confirmation fills.
#
# Host-owned units and storage; the application is deployed separately, like
# CLIProxyAPI. scripts/pi-assistant-deploy builds the core, the web app, and
# the tailnet node from their own repositories, copies the closure here, and
# points ${profile} at it. Units do not start until that profile exists.
{ self, ... }:
let
  profile = "/nix/var/nix/profiles/per-user/pi-assistant/application";
  stateOf = name: "/var/lib/pi-assistant-${name}";
  notebookDir = "/var/lib/pi-household-notebook";
  tsgoState = "/var/lib/assistant-tsgo";
in
{
  # Each instance must stay its own user, private, persisted, and on loopback.
  perSystem =
    { pkgs, lib, ... }:
    let
      problems = lib.concatLists (
        lib.mapAttrsToList (
          host: system:
          let
            c = system.config;
            cfg = c.mountainous.features.pi-assistant or null;
            names = lib.attrNames cfg.people ++ [ "household" ];
            persisted = lib.listToAttrs (
              map (entry: lib.nameValuePair entry.directory entry) (
                lib.filter (
                  entry: !builtins.isString entry
                ) c.environment.persistence."/tundra/permafrost".directories
              )
            );
            want = ok: msg: lib.optional (!ok) "${host}: ${msg}";
            unit = name: c.systemd.services."pi-assistant-${name}";
          in
          lib.optionals (cfg != null && cfg.people != { }) (
            lib.concatMap (
              name:
              let
                service = unit name;
                dir = persisted.${stateOf name} or null;
              in
              want (service.serviceConfig.User == "pi-${name}") "pi-assistant-${name} does not run as pi-${name}"
              ++ want (
                dir != null && dir.user == "pi-${name}" && dir.mode == "0700"
              ) "${stateOf name} is not persisted 0700 for pi-${name}"
              ++ want (!(service.environment ? ASSISTANT_HOST)) "pi-assistant-${name} sets ASSISTANT_HOST"
              ++ want (lib.elem "household" service.serviceConfig.SupplementaryGroups) "pi-${name} cannot write the notebook"
            ) names
            ++ want (
              (persisted.${notebookDir} or { mode = ""; }).mode == "2770"
              && persisted.${notebookDir}.group == "household"
            ) "the notebook directory is not 2770 for the household group"
            ++ want (
              lib.length (lib.unique (map (name: (unit name).serviceConfig.User) names)) == lib.length names
            ) "two instances share a user"
            ++ want (persisted ? ${tsgoState}) "the tailnet node's identity is not persisted"
          )
        ) self.nixosConfigurations
      );
    in
    {
      checks.pi-assistant =
        if problems == [ ] then
          pkgs.runCommand "pi-assistant" { } "touch $out"
        else
          throw "pi-assistant:\n  ${lib.concatStringsSep "\n  " problems}";
    };

  nixos.modules.pi-assistant =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.mountainous.features.pi-assistant;
      people = lib.attrNames cfg.people;
      instances = lib.mapAttrs (name: ports: ports // { person = name; }) cfg.people // {
        household = cfg.household // {
          person = null;
        };
      };

      # The model settings a new home starts from: the instance copies these
      # once, then they are its own.
      settingsSeed = pkgs.writeText "pi-assistant-settings.json" (
        builtins.toJSON {
          defaultProvider = "cliproxyapi";
          defaultModel = lib.removePrefix "cliproxyapi/" cfg.lanes.chat;
          enabledModels = lib.unique (lib.attrValues cfg.lanes);
        }
      );
      lanesSeed = pkgs.writeText "pi-assistant-model-lanes.json" (
        builtins.toJSON {
          version = 3;
          inherit (cfg) lanes;
          fallbacks = cfg.laneFallbacks;
        }
      );

      # Search: CLIProxyAPI's OpenAI search first, then Brave, then keyless.
      # Keys stay in the unit's credentials; pi-web-access runs the command.
      webSearch =
        name:
        pkgs.writeText "pi-assistant-web-search-${name}.json" (
          builtins.toJSON {
            toolActivation = "eager";
            workflow = "none";
            autoOpenBrowser = false;
            openaiResponsesUrl = "http://127.0.0.1:${toString cfg.cliproxyapiPort}/v1/responses";
            openaiApiKey = "!cat /run/credentials/pi-assistant-${name}.service/cliproxyapi-key";
            openaiSearchModel = cfg.searchModel;
            braveApiKey = "!cat /run/credentials/pi-assistant-${name}.service/brave-api-key";
            searchRouting = {
              providers = [
                "openai"
                "brave"
                "exa"
                "duckduckgo"
              ];
              useCurrentModel = false;
              fallbackOn = [
                "unsupported"
                "transient"
                "quota"
                "network"
                "invalid-response"
              ];
            };
          }
        );

      # Runs as the instance's user before each start. It keeps the host's
      # proxy address and key current in the home, and seeds a new home.
      prepare =
        name:
        pkgs.writeShellApplication {
          name = "pi-assistant-${name}-prepare";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.jq
          ];
          text = ''
            umask 077
            state=${stateOf name}
            mkdir -p "$state/seed" "$state/agent" "$state/workspace"
            key=$(cat "$CREDENTIALS_DIRECTORY/cliproxyapi-key")
            jq -n --arg key "$key" '{baseUrl: "http://127.0.0.1:${toString cfg.cliproxyapiPort}", apiKey: $key}' \
              > "$state/seed/cliproxyapi.json"
            cp --no-preserve=mode ${settingsSeed} "$state/seed/settings.json"
            if [ -f "$state/agent/cliproxyapi.json" ]; then
              jq --arg key "$key" '.baseUrl = "http://127.0.0.1:${toString cfg.cliproxyapiPort}" | .apiKey = $key' \
                "$state/agent/cliproxyapi.json" > "$state/agent/cliproxyapi.json.new"
              mv "$state/agent/cliproxyapi.json.new" "$state/agent/cliproxyapi.json"
            fi
            cp --no-preserve=mode ${webSearch name} "$state/agent/web-search.json"
            if [ ! -f "$state/model-lanes.json" ]; then
              cp --no-preserve=mode ${lanesSeed} "$state/model-lanes.json"
            fi
          '';
        };

      environmentOf =
        name: instance:
        {
          ASSISTANT_HOME = stateOf name;
          HOME = stateOf name;
          PI_OPERATOR_AGENT_DIR = "${stateOf name}/seed";
          ASSISTANT_PORT = toString instance.voicePort;
          ASSISTANT_WEB_PORT = toString instance.webPort;
          ASSISTANT_WEB_ROOT = "${profile}/share/assistant-web";
          ASSISTANT_WEB_ORIGINS = "https://${cfg.tailnetName}.${cfg.tailnet}";
          ASSISTANT_WEB_AUTH = "tailnet";
          ASSISTANT_HOME_PLACE = cfg.homePlace;
          ASSISTANT_PEOPLE = lib.concatStringsSep "," people;
          ASSISTANT_NOTEBOOK = "${notebookDir}/notebook.jsonl";
        }
        // lib.optionalAttrs (instance.person != null) { ASSISTANT_PERSON = instance.person; }
        // lib.optionalAttrs (instance.person == null) { ASSISTANT_HOUSEHOLD = "1"; }
        // lib.optionalAttrs (cfg.speechUrl != null) { ASSISTANT_SPEECH_URL = cfg.speechUrl; };

      portsOption = voice: web: {
        voicePort = lib.mkOption {
          type = lib.types.port;
          default = voice;
        };
        webPort = lib.mkOption {
          type = lib.types.port;
          default = web;
        };
      };
    in
    {
      options.mountainous.features.pi-assistant = {
        people = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule { options = portsOption 4317 4318; });
          default = { };
          example = {
            simon = {
              voicePort = 4317;
              webPort = 4318;
            };
          };
          description = "Each person's own assistant, by name, with its loopback ports. Names sort alphabetically in the app's picker.";
        };
        household = portsOption 4337 4338;
        tailnet = lib.mkOption {
          type = lib.types.str;
          example = "example.ts.net";
        };
        tailnetName = lib.mkOption {
          type = lib.types.str;
          default = "assistant";
        };
        homePlace = lib.mkOption {
          type = lib.types.str;
          description = "ASSISTANT_HOME_PLACE: name|latitude|longitude|timezone.";
        };
        cliproxyapiPort = lib.mkOption {
          type = lib.types.port;
          default = 8317;
        };
        cliproxyapiKeyFile = lib.mkOption { type = lib.types.path; };
        braveApiKeyFile = lib.mkOption { type = lib.types.path; };
        searchModel = lib.mkOption {
          type = lib.types.str;
          default = "gpt-5.6-luna";
        };
        speechUrl = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "An OpenAI-compatible speech service for the voice link.";
        };
        lanes = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          description = "The model lanes a new home starts with.";
        };
        laneFallbacks = lib.mkOption {
          type = lib.types.attrsOf (lib.types.listOf lib.types.str);
          default = { };
        };
      };

      config = lib.mkIf (cfg.people != { }) {
        assertions = [
          {
            assertion = !(cfg.people ? household);
            message = "pi-assistant: \"household\" is the shared instance, not a person.";
          }
          {
            assertion =
              let
                ports = lib.concatMap (instance: [
                  instance.voicePort
                  instance.webPort
                ]) (lib.attrValues instances);
              in
              lib.length (lib.unique ports) == lib.length ports;
            message = "pi-assistant: two instances share a port.";
          }
        ];

        # The deploy script sets this profile; units wait for it.
        systemd.tmpfiles.rules = [ "d /nix/var/nix/profiles/per-user/pi-assistant 0755 root root -" ];

        users.groups = {
          household = { };
          assistant-tsgo = { };
        }
        // lib.mapAttrs' (name: _: lib.nameValuePair "pi-${name}" { }) instances;
        users.users = {
          assistant-tsgo = {
            isSystemUser = true;
            group = "assistant-tsgo";
            home = tsgoState;
          };
        }
        // lib.mapAttrs' (
          name: _:
          lib.nameValuePair "pi-${name}" {
            isSystemUser = true;
            group = "pi-${name}";
            extraGroups = [ "household" ];
            home = stateOf name;
            description = "Pi assistant for ${name}";
          }
        ) instances;

        # Root is tmpfs. Conversations, memory, and the tailnet identity live
        # on the persistent volume.
        environment.persistence."/tundra/permafrost".directories =
          lib.mapAttrsToList (name: _: {
            directory = stateOf name;
            user = "pi-${name}";
            group = "pi-${name}";
            mode = "0700";
          }) instances
          ++ [
            {
              directory = notebookDir;
              user = "root";
              group = "household";
              mode = "2770";
            }
            {
              directory = tsgoState;
              user = "assistant-tsgo";
              group = "assistant-tsgo";
              mode = "0700";
            }
          ];

        systemd.services =
          lib.mapAttrs' (
            name: instance:
            lib.nameValuePair "pi-assistant-${name}" {
              description = "Pi assistant: ${name}";
              wantedBy = [ "multi-user.target" ];
              wants = [ "network-online.target" ];
              after = [
                "network-online.target"
                "cliproxyapi.service"
              ];
              environment = environmentOf name instance;
              unitConfig = {
                ConditionPathExists = "${profile}/bin/assistant";
                RequiresMountsFor = [
                  (stateOf name)
                  notebookDir
                ];
              };
              serviceConfig = {
                User = "pi-${name}";
                Group = "pi-${name}";
                SupplementaryGroups = [ "household" ];
                WorkingDirectory = "${stateOf name}/workspace";
                LoadCredential = [
                  "cliproxyapi-key:${cfg.cliproxyapiKeyFile}"
                  "brave-api-key:${cfg.braveApiKeyFile}"
                ];
                ExecStartPre = "${prepare name}/bin/pi-assistant-${name}-prepare";
                ExecStart = "${profile}/bin/assistant serve";
                # The notebook is 0660 and the household group writes it.
                UMask = "0007";
                Restart = "on-failure";
                RestartSec = 3;
                TimeoutStopSec = 30;
                NoNewPrivileges = true;
                ProtectSystem = "strict";
                ProtectHome = true;
                ReadWritePaths = [
                  (stateOf name)
                  notebookDir
                ];
                PrivateTmp = true;
                PrivateDevices = true;
                ProtectKernelTunables = true;
                ProtectKernelModules = true;
                ProtectControlGroups = true;
                RestrictSUIDSGID = true;
                LockPersonality = true;
                RestrictAddressFamilies = [
                  "AF_UNIX"
                  "AF_INET"
                  "AF_INET6"
                ];
              };
            }
          ) instances
          // {
            assistant-tsgo = {
              description = "Assistant tailnet node: https://${cfg.tailnetName}.${cfg.tailnet}";
              wantedBy = [ "multi-user.target" ];
              wants = [ "network-online.target" ];
              after = [
                "network-online.target"
              ]
              ++ lib.mapAttrsToList (name: _: "pi-assistant-${name}.service") instances;
              unitConfig = {
                ConditionPathExists = "${profile}/bin/assistant-tsgo";
                RequiresMountsFor = [ tsgoState ];
              };
              serviceConfig = {
                User = "assistant-tsgo";
                Group = "assistant-tsgo";
                ExecStart = lib.concatStringsSep " " (
                  [
                    "${profile}/bin/assistant-tsgo"
                    "--name ${cfg.tailnetName}"
                    "--expected-fqdn ${cfg.tailnetName}.${cfg.tailnet}"
                    "--state ${tsgoState}"
                    "--household http://127.0.0.1:${toString cfg.household.webPort}"
                  ]
                  ++ lib.mapAttrsToList (
                    name: ports:
                    "--person ${name}=http://127.0.0.1:${toString ports.webPort},http://127.0.0.1:${toString ports.voicePort}"
                  ) cfg.people
                );
                UMask = "0077";
                Restart = "on-failure";
                RestartSec = 3;
                NoNewPrivileges = true;
                ProtectSystem = "strict";
                ProtectHome = true;
                ReadWritePaths = [ tsgoState ];
                PrivateTmp = true;
                PrivateDevices = true;
                ProtectKernelTunables = true;
                ProtectKernelModules = true;
                ProtectControlGroups = true;
                RestrictSUIDSGID = true;
                LockPersonality = true;
              };
            };
          };
      };
    };
}
