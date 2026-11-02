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
            gateway = c.mountainous.features.ai-gateway.enable or false;
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
              ++ want (lib.any (lib.hasPrefix "d ${service.serviceConfig.WorkingDirectory} ") c.systemd.tmpfiles.rules) "pi-assistant-${name}'s working directory is not created before it starts"
              # An app runs as its person, on loopback only, with data in the person's state.
              ++ want (
                (cfg.people.${name}.apps or { }) == { }
                || lib.elem "d ${stateOf name}/apps 0700 pi-${name} pi-${name} -" c.systemd.tmpfiles.rules
              ) "${stateOf name}/apps is not created for pi-${name} before its apps start"
              ++ lib.concatMap (
                app:
                let
                  appUnit = c.systemd.services."assistant-app-${name}-${app}";
                in
                want (appUnit.serviceConfig.User == "pi-${name}") "assistant-app-${name}-${app} does not run as pi-${name}"
                ++ want (appUnit.environment.HOST == "127.0.0.1") "assistant-app-${name}-${app} is not loopback only"
                ++ want (lib.hasPrefix "${stateOf name}/apps/" appUnit.environment.STATE_DIRECTORY) "assistant-app-${name}-${app} keeps data outside ${name}'s state"
              ) (lib.attrNames (cfg.people.${name}.apps or { }))
              ++ lib.optionals gateway (
                want (
                  lib.elem "ai-gateway.service" service.wants
                  && lib.elem "ai-gateway.service" service.after
                  && lib.elem "cliproxyapi.service" service.after
                ) "pi-assistant-${name} must start after the front door and login keeper"
                ++ want (lib.elem "cliproxyapi-key:${c.sops.secrets.ai-gateway-key-assistant-rakku.path}" service.serviceConfig.LoadCredential) "pi-assistant-${name} does not load its front-door key"
                ++ want (
                  lib.elem "decide-api-key:${c.sops.secrets.ai-gateway-key-assistant-rakku.path}" service.serviceConfig.LoadCredential
                  && (service.environment.ASSISTANT_DECIDE_URL or null) == "http://127.0.0.1:8430/v1"
                ) "pi-assistant-${name} does not ask Jev through the front door"
              )
            ) names
            ++ want (
              (persisted.${notebookDir} or { mode = ""; }).mode == "2770"
              && persisted.${notebookDir}.group == "household"
            ) "the notebook directory is not 2770 for the household group"
            ++ want (
              lib.length (lib.unique (map (name: (unit name).serviceConfig.User) names)) == lib.length names
            ) "two instances share a user"
            ++ want (persisted ? ${tsgoState}) "the tailnet node's identity is not persisted"
            ++ lib.optionals gateway (
              want (cfg.cliproxyapiPort == 8430) "assistant port does not point at the production front door"
              ++ want (
                cfg.cliproxyapiKeyFile == c.sops.secrets.ai-gateway-key-assistant-rakku.path
              ) "assistant does not use its dedicated gateway grant"
              ++ want (lib.all
                (
                  model: lib.elem model (builtins.head c.mountainous.features.ai-gateway.settings.gateway_keys).models
                )
                (
                  [ cfg.searchModel ]
                  ++ map (lib.removePrefix "cliproxyapi/") (
                    lib.attrValues cfg.lanes ++ lib.concatLists (lib.attrValues cfg.laneFallbacks)
                  )
                )
              ) "assistant lanes or web search request a model outside the gateway grant"
              ++ want (
                let
                  grant = builtins.head c.mountainous.features.ai-gateway.settings.gateway_keys;
                in
                lib.elem "jev" grant.models && lib.elem "systemone" grant.dialects
              ) "the assistant grant does not allow Jev (model jev, dialect systemone)"
              ++ want (
                lib.all (
                  name:
                  lib.elem "pi-assistant-${name}.service" c.sops.secrets.ai-gateway-key-assistant-rakku.restartUnits
                ) names
                && lib.elem "ai-gateway.service" c.sops.secrets.ai-gateway-key-assistant-rakku.restartUnits
              ) "assistant key rotation must restart the gateway and its clients"
            )
          )
        ) self.nixosConfigurations
      );
    in
    {
      checks.pi-assistant-skills =
        pkgs.runCommand "pi-assistant-skills"
          {
            nativeBuildInputs = [
              pkgs.bash
              pkgs.coreutils
              pkgs.shellcheck
            ];
          }
          ''
            mkdir -p modules scripts
            cp ${./pi-assistant-skills.sh} modules/pi-assistant-skills.sh
            cp ${../scripts/test-pi-assistant-skills} scripts/test-pi-assistant-skills
            bash scripts/test-pi-assistant-skills
            touch "$out"
          '';
      checks.pi-assistant-resources =
        if import ../tests/pi-assistant-resources.nix { flake = self; } then
          pkgs.runCommand "pi-assistant-resources" { } "touch $out"
        else
          throw "pi-assistant: instance resource contract failed";
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
      # With the front door, core asks Jev (reflexes, thread choice, recall;
      # assistant ADR 0001) through it, on the same grant as the chat lanes.
      frontDoor = config.mountainous.features.ai-gateway.enable or false;
      people = lib.attrNames cfg.people;
      # Every instance gets the feature's shared skills; its own entry of the
      # same name wins.
      withShared = instance: instance // { skills = cfg.sharedSkills // (instance.skills or { }); };
      instances =
        lib.mapAttrs (name: ports: withShared (ports // { person = name; })) cfg.people
        // {
          household = withShared (
            cfg.household
            // {
              person = null;
            }
          );
        };

      # The model settings a new home starts from: the instance copies these
      # once, then they are its own.
      settingsSeed = pkgs.writeText "pi-assistant-settings.json" (
        builtins.toJSON {
          defaultProvider = "cliproxyapi";
          defaultModel = lib.removePrefix "cliproxyapi/" cfg.lanes.chat;
          defaultThinkingLevel = cfg.thinkingLevel;
          # A fallback that is not enabled resolves to no model, and the
          # instance refuses to start. Enable every lane model and fallback.
          enabledModels = lib.unique (
            lib.attrValues cfg.lanes ++ lib.concatLists (lib.attrValues cfg.laneFallbacks)
          );
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

      # External apps (core ADR 0006): the file core reads. No apps, no file.
      mcpAppsOf =
        name:
        pkgs.writeText "pi-assistant-mcp-apps-${name}.json" (
          builtins.toJSON {
            servers = lib.mapAttrsToList (app: spec: {
              id = lib.replaceStrings [ "-" ] [ "_" ] app;
              inherit (spec) title readOnlyTools;
              url = "http://127.0.0.1:${toString spec.port}/mcp";
            }) (instances.${name}.apps or { });
          }
        );
      appsOf = name: instances.${name}.apps or { };

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
            # A home made before thinkingLevel existed gets it once; a level
            # the person set later stays theirs.
            if [ -f "$state/agent/settings.json" ]; then
              jq --arg level ${lib.escapeShellArg cfg.thinkingLevel} '.defaultThinkingLevel //= $level' \
                "$state/agent/settings.json" > "$state/agent/settings.json.new"
              mv "$state/agent/settings.json.new" "$state/agent/settings.json"
            fi
            cp --no-preserve=mode ${webSearch name} "$state/agent/web-search.json"
            ${
              if appsOf name == { } then
                ''rm -f "$state/mcp-apps.json"''
              else
                ''cp --no-preserve=mode ${mcpAppsOf name} "$state/mcp-apps.json"''
            }
            ${lib.optionalString (cfg.groceries != null) ''
              # The core wants an owner-only 0600 file. The credential is root's,
              # with an ACL for this user, so it is copied.
              mkdir -p "$state/.config/assistant"
              install -m 600 "$CREDENTIALS_DIRECTORY/groceries-service-token" \
                "$state/.config/assistant/groceries-service-token"
            ''}
            if [ ! -f "$state/model-lanes.json" ]; then
              cp --no-preserve=mode ${lanesSeed} "$state/model-lanes.json"
            fi
            ${pkgs.bash}/bin/bash ${./pi-assistant-skills.sh} "$state/agent" ${
              lib.escapeShellArgs (
                lib.concatLists (
                  lib.mapAttrsToList (skill: source: [
                    skill
                    source
                  ]) (instances.${name}.skills or { })
                )
              )
            }
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
          ASSISTANT_WEB_ORIGINS = lib.concatStringsSep "," (
            [ "https://${cfg.tailnetName}.${cfg.tailnet}" ] ++ cfg.extraWebOrigins
          );
          ASSISTANT_WEB_AUTH = "tailnet";
          ASSISTANT_HOME_PLACE = cfg.homePlace;
          ASSISTANT_PEOPLE = lib.concatStringsSep "," people;
          ASSISTANT_NOTEBOOK = "${notebookDir}/notebook.jsonl";
        }
        // lib.optionalAttrs (instance.person != null) { ASSISTANT_PERSON = instance.person; }
        // lib.optionalAttrs (instance.person == null) { ASSISTANT_HOUSEHOLD = "1"; }
        // lib.optionalAttrs (cfg.speechUrl != null) { ASSISTANT_SPEECH_URL = cfg.speechUrl; }
        // lib.optionalAttrs frontDoor {
          ASSISTANT_DECIDE_URL = "http://127.0.0.1:${toString cfg.cliproxyapiPort}/v1";
        }
        // lib.optionalAttrs (instance.logbook or false) {
          # Training tools and the training live-UI domain (assistant core). Core
          # also refuses them for anyone but Simon's personal instance.
          ASSISTANT_LOGBOOK_URL = "http://127.0.0.1:3160";
        }
        // lib.optionalAttrs (cfg.groceries != null) {
          ASSISTANT_GROCERIES_BASE_URL = cfg.groceries.url;
          # ExecStartPre copies the credential here (see prepare).
          ASSISTANT_GROCERIES_TOKEN_PATH = "${stateOf name}/.config/assistant/groceries-service-token";
        };

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

      # Personal and Household instances use the same reviewed resources.
      resourceOptions = {
        skills = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          example = {
            scryer = "/nix/var/nix/profiles/per-user/pi-assistant/skills/scryer";
          };
          description = "Shared skill directories linked into this assistant's own agent directory. Sources must be absolute paths containing SKILL.md.";
        };
        credentials = lib.mkOption {
          type = lib.types.attrsOf lib.types.path;
          default = { };
          example = {
            beszel-mcp-token = "/run/secrets/beszel-mcp-token";
          };
          description = "More secrets for this assistant, by name. Its tools read each one as $CREDENTIALS_DIRECTORY/<name>.";
        };
      };

      # Whether an instance acts on GitHub as the operator (modules/github.nix).
      githubOf = instance: instance.github or false;
    in
    {
      options.mountainous.features.pi-assistant = {
        sharedPackages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          example = lib.literalExpression "[ pkgs.agent-browser pkgs.chromium ]";
          description = "Commands on every assistant's PATH: each person's and the Household's. Use it for the programs a shared skill runs.";
        };
        sharedSkills = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          example = {
            agents = "/nix/var/nix/profiles/per-user/pi-assistant/skills/agents";
          };
          description = "Skills linked into every assistant: each person's and the Household's. A source is an absolute path to one skill (it holds SKILL.md) or to a collection of skills (its subdirectories hold SKILL.md); Pi reads a collection recursively. An instance's own skills entry of the same name wins.";
        };
        people = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options =
                portsOption 4317 4318
                // resourceOptions
                // {
                  github = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                    description = "Give this person's assistant the fleet's GitHub token, so its gh and git act as the operator.";
                  };
                  logbook = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                    description = "Give this person's assistant the training tools, which read and write this host's Logbook on loopback.";
                  };
                  apps = lib.mkOption {
                    type = lib.types.attrsOf (
                      lib.types.submodule {
                        options = {
                          title = lib.mkOption {
                            type = lib.types.str;
                            description = "The app's name in the assistant, such as \"To-do board\".";
                          };
                          port = lib.mkOption {
                            type = lib.types.port;
                            description = "The app's loopback port.";
                          };
                          readOnlyTools = lib.mkOption {
                            type = lib.types.listOf lib.types.str;
                            default = [ ];
                            description = "Tools that only read. Core counts every other call as a change.";
                          };
                        };
                      }
                    );
                    default = { };
                    example = {
                      todo-board = {
                        title = "To-do board";
                        port = 3170;
                        readOnlyTools = [ "list_todos" "board_state" ];
                      };
                    };
                    description = "This person's own apps (assistant/apps, core ADR 0006), by package name. Each runs as this person's user on loopback, keeps its data in the person's state, and shows in their assistant through mcp-apps.json.";
                  };
                };
            }
          );
          default = { };
          example = {
            simon = {
              voicePort = 4317;
              webPort = 4318;
            };
          };
          description = "Each person's own assistant, by name, with its loopback ports. Names sort alphabetically in the app's picker.";
        };
        household = portsOption 4337 4338 // resourceOptions;
        tailnet = lib.mkOption {
          type = lib.types.str;
          example = "example.ts.net";
        };
        tailnetName = lib.mkOption {
          type = lib.types.str;
          default = "assistant";
        };
        extraWebOrigins = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "https://vela.example.ts.net" ];
          description = "More exact browser origins for ASSISTANT_WEB_ORIGINS, beside the assistant's own: other apps that call the assistant, such as Vela.";
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
        groceries = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.submodule {
              options = {
                url = lib.mkOption {
                  type = lib.types.str;
                  example = "https://groceries.example.ts.net";
                  description = "ASSISTANT_GROCERIES_BASE_URL: the groceries app's HTTPS origin.";
                };
                tokenFile = lib.mkOption {
                  type = lib.types.path;
                  description = "The shared service token. Every instance reads it as the groceries-service-token credential.";
                };
              };
            }
          );
          default = null;
          description = "The household groceries app, which the assistants call with a shared service token.";
        };
        lanes = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          description = "The model lanes a new home starts with.";
        };
        thinkingLevel = lib.mkOption {
          type = lib.types.enum [
            "off"
            "minimal"
            "low"
            "medium"
            "high"
            "xhigh"
          ];
          default = "medium";
          description = "The thinking level a new conversation starts with (Pi defaultThinkingLevel). Seeds a new home, and fills it into an existing home that has none.";
        };
        laneFallbacks = lib.mkOption {
          type = lib.types.attrsOf (lib.types.listOf lib.types.str);
          description = "Fallback models per lane. The core refuses a lanes file that leaves a lane out.";
        };
        installedSkills = lib.mkOption {
          type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
          readOnly = true;
          internal = true;
          description = "The skills each instance links, by instance: sharedSkills with its own skills over them.";
        };
      };

      config = lib.mkIf (cfg.people != { }) {
        mountainous.features.pi-assistant.installedSkills = lib.mapAttrs (
          _: instance: instance.skills
        ) instances;
        assertions = [
          {
            assertion = !(cfg.people ? household);
            message = "pi-assistant: \"household\" is the shared instance, not a person.";
          }
          {
            assertion =
              let
                ports = lib.concatMap (
                  instance:
                  [
                    instance.voicePort
                    instance.webPort
                  ]
                  ++ map (app: app.port) (lib.attrValues (instance.apps or { }))
                ) (lib.attrValues instances);
              in
              lib.length (lib.unique ports) == lib.length ports;
            message = "pi-assistant: two instances share a port.";
          }
          {
            assertion =
              let
                lanes = [
                  "background"
                  "chat"
                  "creative"
                  "mechanical"
                ];
              in
              lib.attrNames cfg.lanes == lanes && lib.attrNames cfg.laneFallbacks == lanes;
            message = "pi-assistant: lanes and laneFallbacks must each name chat, creative, mechanical, and background.";
          }
        ];

        # The deploy script sets this profile; units wait for it. Each unit's
        # WorkingDirectory is its workspace, which a new, empty home lacks:
        # systemd changes into it before ExecStartPre can create it.
        systemd.tmpfiles.rules = [
          "d /nix/var/nix/profiles/per-user/pi-assistant 0755 root root -"
        ]
        ++ lib.mapAttrsToList (
          name: _: "d ${stateOf name}/workspace 0700 pi-${name} pi-${name} -"
        ) instances
        # Each app's data directory, inside its person's persisted state.
        ++ lib.concatLists (
          lib.mapAttrsToList (
            name: _:
            # The parent first: tmpfiles refuses a root-owned step under the
            # person's own directory ("unsafe path transition").
            lib.optional (appsOf name != { }) "d ${stateOf name}/apps 0700 pi-${name} pi-${name} -"
            ++ lib.mapAttrsToList (app: _: "d ${stateOf name}/apps/${app} 0700 pi-${name} pi-${name} -") (appsOf name)
          ) instances
        );

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
              wants = [
                "network-online.target"
              ]
              ++ lib.optional (config.mountainous.features.ai-gateway.enable or false) "ai-gateway.service"
              ++ lib.mapAttrsToList (app: _: "assistant-app-${name}-${app}.service") (appsOf name);
              after = [
                "network-online.target"
                "cliproxyapi.service"
              ]
              ++ lib.optional (config.mountainous.features.ai-gateway.enable or false) "ai-gateway.service"
              ++ lib.mapAttrsToList (app: _: "assistant-app-${name}-${app}.service") (appsOf name);
              environment = environmentOf name instance;
              # The application brings its own tools; the host adds the signed-in
              # gh and the commands the shared skills run.
              path = cfg.sharedPackages ++ lib.optional (githubOf instance) config.mountainous.github.package;
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
                ]
                # Core reads $CREDENTIALS_DIRECTORY/decide-api-key for Jev.
                ++ lib.optional frontDoor "decide-api-key:${cfg.cliproxyapiKeyFile}"
                ++ lib.optional (githubOf instance) "github-token:${config.sops.secrets.github-token.path}"
                ++ lib.optional (cfg.groceries != null) "groceries-service-token:${cfg.groceries.tokenFile}"
                ++ lib.mapAttrsToList (name: file: "${name}:${file}") (instance.credentials or { });
                # Scratch clones of repositories: on disk, never persisted,
                # safe to delete. $CACHE_DIRECTORY points here.
                CacheDirectory = "pi-assistant-${name}";
                CacheDirectoryMode = "0700";
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
          # Each person's apps: the person's own user, loopback, data in their state.
          // lib.concatMapAttrs (
            name: _:
            lib.mapAttrs' (
              app: spec:
              lib.nameValuePair "assistant-app-${name}-${app}" {
                description = "${spec.title} for ${name}'s assistant";
                wantedBy = [ "multi-user.target" ];
                environment = {
                  HOST = "127.0.0.1";
                  PORT = toString spec.port;
                  STATE_DIRECTORY = "${stateOf name}/apps/${app}";
                };
                unitConfig = {
                  ConditionPathExists = "${profile}/bin/${app}";
                  RequiresMountsFor = [ (stateOf name) ];
                };
                serviceConfig = {
                  User = "pi-${name}";
                  Group = "pi-${name}";
                  ExecStart = "${profile}/bin/${app}";
                  UMask = "0077";
                  Restart = "on-failure";
                  RestartSec = 3;
                  NoNewPrivileges = true;
                  ProtectSystem = "strict";
                  ProtectHome = true;
                  ReadWritePaths = [ "${stateOf name}/apps/${app}" ];
                  PrivateTmp = true;
                  PrivateDevices = true;
                  ProtectKernelTunables = true;
                  ProtectKernelModules = true;
                  ProtectControlGroups = true;
                  RestrictSUIDSGID = true;
                  LockPersonality = true;
                  RestrictAddressFamilies = [
                    "AF_INET"
                    "AF_INET6"
                  ];
                };
              }
            ) (appsOf name)
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
