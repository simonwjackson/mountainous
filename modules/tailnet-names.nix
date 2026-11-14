# A host's own tailnet names (https://<name>.<tailnet>), one per local
# backend: Rakku's home services, Unzen's Valhalla and Traccar.
#
# Every name joins with the fleet OAuth client, the same credential that
# tailscale-join and the media identities use. Tailscale makes a one-hour,
# single-use, tagged key for each first join, and tagged nodes have no key
# expiry. No per-host auth key exists to expire.
#
# The saved state owns the identity after the first join. If a name's node is
# deleted from the tailnet, remove its state directory and restart the unit to
# join again.
{ inputs, self, ... }:
{
  # No host may join a tailnet name with a stored auth key. Those expire.
  perSystem =
    { pkgs, lib, ... }:
    let
      problems = lib.concatLists (
        lib.mapAttrsToList (
          host: system:
          let
            c = system.config;
          in
          lib.optional (
            c ? sops && c.sops.secrets ? tailscale-ephemeral
          ) "${host}: tailscale-ephemeral auth key is back"
          ++ lib.concatLists (
            lib.mapAttrsToList (
              name: _:
              let
                unit = c.systemd.services."tsnet-proxy-${name}";
              in
              lib.optional (
                !(lib.hasInfix "-oauth-secret-file" unit.serviceConfig.ExecStart)
                || (unit.environment ? TS_AUTHKEY)
                || lib.hasInfix "TS_AUTHKEY" (unit.script or "")
              ) "${host}: tailnet name ${name} does not join with the fleet OAuth client"
            ) c.mountainous.tailnetNames or { }
          )
          # Fixed ids only where the root forgets allocated ones.
          ++ lib.optionals ((c.mountainous.tailnetNames or { }) != { }) (
            let
              tmpfsRoot = system.options.environment ? persistence;
              user = c.users.users.tsnet-proxy;
              group = c.users.groups.tsnet-proxy;
            in
            lib.optional (
              if tmpfsRoot then user.uid != 991 || group.gid != 989 else user.uid != null || group.gid != null
            ) "${host}: tsnet-proxy has ${if tmpfsRoot then "no fixed" else "a fixed"} uid/gid"
          )
        ) self.nixosConfigurations
      );
    in
    {
      checks.tailnet-names =
        if problems == [ ] then
          pkgs.runCommand "tailnet-names" { } "touch $out"
        else
          throw "tailnet names:\n  ${lib.concatStringsSep "\n  " problems}";
    };

  nixos.modules.tailnet-names =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      names = config.mountainous.tailnetNames;
      proxy = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.media-tsnet-proxy;
      routeTable =
        name: cfg:
        pkgs.writeText "tsnet-proxy-${name}-mcp.json" (
          builtins.toJSON (
            lib.mapAttrs (
              tool: row:
              {
                inherit (row) callerNodeIds mcpTools;
              }
              // lib.optionalAttrs (row.backend != null) { inherit (row) backend; }
              // lib.optionalAttrs (row.mcpResources != [ ]) { inherit (row) mcpResources; }
              // lib.optionalAttrs (row.bearerCredentialFile != null) {
                bearerCredential = "mcp-${tool}";
              }
              // lib.optionalAttrs (row.scryer != null) {
                scryer = {
                  inherit (row.scryer) url username;
                  passwordCredential = "mcp-${tool}";
                };
              }
              // lib.optionalAttrs (row.webSearch != null) {
                webSearch = {
                  inherit (row.webSearch) url model;
                  keyCredential = "mcp-${tool}";
                };
              }
            ) cfg.mcpRoutes
          )
        );
      # The secret systemd copies for a row: its Bearer key, its Scryer
      # password or its web search key.
      rowCredential =
        row:
        if row.scryer != null then
          row.scryer.passwordFile
        else if row.webSearch != null then
          row.webSearch.keyFile
        else
          row.bearerCredentialFile;
      # Scryer's own tools (packages/media-tsnet-proxy/scryer.go, scryer_app.go).
      scryerTools = import ../lib/openclaw-scryer-tools.nix;
      directory = name: "/var/lib/tsnet-proxy-${name}";
      # A new subdirectory: the old, dead TS_AUTHKEY state stays beside it.
      state = name: "${directory name}/tailnet";
      tailscale = config.mountainous.tailscale;
      # Rakku's root is tmpfs, so the identities live on its persistent
      # volume. A host with a persistent root (Unzen) keeps them in /var/lib.
      #
      # The fixed ids belong to that case too: on a tmpfs root NixOS forgets
      # the ids it handed out, and the persisted state must keep its owner.
      # On a persistent root NixOS remembers them (/var/lib/nixos), so the
      # account takes a free id there; a fixed one could match an id already
      # handed to another account.
      persistence =
        { options, ... }:
        {
          config = lib.optionalAttrs (options.environment ? persistence) {
            users.users.tsnet-proxy.uid = 991;
            users.groups.tsnet-proxy.gid = 989;
            environment.persistence."/tundra/permafrost".directories = lib.mapAttrsToList (name: _: {
              directory = directory name;
              user = "tsnet-proxy";
              group = "tsnet-proxy";
              mode = "0700";
            }) names;
          };
        };
    in
    {
      imports = [ persistence ];

      options.mountainous.tailnetNames = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              backend = lib.mkOption {
                type = lib.types.str;
                example = "http://127.0.0.1:8123";
              };
              after = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
              };
              description = lib.mkOption { type = lib.types.str; };
              tags = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = tailscale.tags;
                description = "Enrollment tags for this service identity.";
              };
              scryerUsername = lib.mkOption {
                type = lib.types.strMatching "[a-zA-Z0-9_-]+";
                default = "admin";
                description = "Account used by the native Scryer MCP endpoint.";
              };
              scryerPasswordFile = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Enable the native account-scoped Scryer MCP endpoint with this LoadCredential password file. Backend is the fixed HTTPS GraphQL URL.";
              };
              webSearchKeyFile = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Enable native web search MCP with this gateway LoadCredential key. Backend is the loopback front-door Responses URL.";
              };
              webSearchModel = lib.mkOption {
                type = lib.types.str;
                default = "gpt-6.1-sol";
                description = "Fixed granted model for native web search.";
              };
              mcpRouting.enable = lib.mkEnableOption "reloadable path-prefixed MCP routing";
              mcpRoutes = lib.mkOption {
                default = { };
                description = "Path-prefixed MCP rows, reloaded without restarting the front-door proxy.";
                type = lib.types.attrsOf (
                  lib.types.submodule {
                    options = {
                      backend = lib.mkOption {
                        type = lib.types.nullOr (lib.types.strMatching "http://127\\.0\\.0\\.1:[0-9]+(/[^?#]*)?");
                        default = null;
                        description = "Fixed loopback MCP URL. An empty path means /mcp. A row has exactly one of backend, scryer or webSearch.";
                      };
                      scryer = lib.mkOption {
                        default = null;
                        description = "Serve this Scryer account's MCP natively, as a claw-scryer-<user> endpoint does: no loopback backend, the password is the row's credential (mcp-<row>).";
                        type = lib.types.nullOr (
                          lib.types.submodule {
                            options = {
                              url = lib.mkOption {
                                type = lib.types.strMatching "https://[a-zA-Z0-9.-]+/[^?#@]*";
                                description = "Fixed HTTPS GraphQL URL.";
                              };
                              username = lib.mkOption { type = lib.types.strMatching "[a-zA-Z0-9_-]+"; };
                              passwordFile = lib.mkOption {
                                type = lib.types.strMatching "/run/[^:]+";
                                description = "Runtime secret source, copied by systemd LoadCredential.";
                              };
                            };
                          }
                        );
                      };
                      webSearch = lib.mkOption {
                        default = null;
                        description = "Serve model-native web search natively, as a webSearchKeyFile endpoint does: no loopback MCP server; the front door's Responses key is the row's credential (mcp-<row>). The only tool is web_search.";
                        type = lib.types.nullOr (
                          lib.types.submodule {
                            options = {
                              url = lib.mkOption {
                                type = lib.types.strMatching "http://127\\.0\\.0\\.1:8430/v1/responses";
                                description = "The fixed loopback front-door Responses URL.";
                              };
                              model = lib.mkOption {
                                type = lib.types.strMatching "[a-zA-Z0-9._-]+";
                                description = "Fixed granted model.";
                              };
                              keyFile = lib.mkOption {
                                type = lib.types.strMatching "/run/[^:]+";
                                description = "Runtime secret source, copied by systemd LoadCredential.";
                              };
                            };
                          }
                        );
                      };
                      mcpResources = lib.mkOption {
                        type = lib.types.listOf (lib.types.strMatching "ui://[^,[:space:]]+");
                        default = [ ];
                        description = "Exact MCP App view URIs a loopback row may list and read. Empty refuses resource methods.";
                      };
                      callerNodeIds = lib.mkOption {
                        # Tailscale's stable IDs have this shape. A node name
                        # such as "zao" or "flakey" fails here, not at runtime.
                        type = lib.types.nonEmptyListOf (lib.types.strMatching "n[a-zA-Z0-9]+CNTRL");
                        description = "Stable Tailscale node IDs from WhoIs (lib/tailnet-nodes.nix). Not node names: a removed node's name can be registered again. No default grant; an empty list fails evaluation.";
                      };
                      mcpTools = lib.mkOption {
                        type = lib.types.nonEmptyListOf (lib.types.strMatching "[a-zA-Z0-9_-]+");
                        description = "Allowed stateless MCP tools for this row.";
                      };
                      bearerCredentialFile = lib.mkOption {
                        type = lib.types.nullOr (lib.types.strMatching "/run/[^:]+");
                        default = null;
                        description = "Optional runtime secret source; copied by systemd LoadCredential, never a caller credential or a store value.";
                      };
                    };
                  }
                );
              };
              mcpResources = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Exact UI resource URI allowlist for filtered MCP. Empty denies resource methods.";
              };
              mcpAllowedNodeIds = lib.mkOption {
                type = lib.types.listOf (lib.types.strMatching "[a-zA-Z0-9]+");
                default = [ ];
                description = "Restrict a filtered MCP endpoint to these stable Tailscale node IDs. Empty preserves the existing any-tailnet-peer policy.";
              };
              mcpTools = lib.mkOption {
                type = lib.types.nullOr (lib.types.nonEmptyListOf (lib.types.strMatching "[a-zA-Z0-9_-]+"));
                default = null;
                description = "When set, serve only these stateless MCP tools, with tailnet peer verification. Empty allowlists are invalid, not an unrestricted proxy. Only initialize, ping, tools/list, allowed tools/call and explicitly listed resource reads/listing are served.";
              };
            };
          }
        );
        default = { };
        description = "Tailnet HTTPS names served from this host, keyed by name.";
      };

      config = lib.mkIf (names != { }) {
        assertions =
          lib.mapAttrsToList (name: cfg: {
            assertion =
              ((cfg.mcpResources == [ ] && cfg.mcpAllowedNodeIds == [ ]) || cfg.mcpTools != null)
              && (
                !cfg.mcpRouting.enable
                || (cfg.mcpTools == null && cfg.scryerPasswordFile == null && cfg.webSearchKeyFile == null)
              )
              && lib.all (tool: builtins.match "[a-zA-Z0-9_-]+" tool != null) (lib.attrNames cfg.mcpRoutes);
            message = "${name}: MCP resources require filtered tools, and path routing cannot use endpoint modes.";
          }) names
          ++ lib.mapAttrsToList (name: cfg: {
            assertion = cfg.mcpRoutes == { } || cfg.mcpRouting.enable;
            message = "${name}: MCP rows require mcpRouting.enable.";
          }) names
          ++ lib.concatLists (
            lib.mapAttrsToList (
              name: cfg:
              lib.mapAttrsToList (tool: row: {
                assertion =
                  lib.count (kind: kind != null) [
                    row.backend
                    row.scryer
                    row.webSearch
                  ] == 1
                  && (
                    if row.scryer != null then
                      row.bearerCredentialFile == null
                      && row.mcpResources == [ ]
                      && lib.all (t: lib.elem t scryerTools) row.mcpTools
                    else if row.webSearch != null then
                      row.bearerCredentialFile == null && row.mcpResources == [ ] && row.mcpTools == [ "web_search" ]
                    else
                      true
                  );
                message = "${name}: /mcp/${tool} needs exactly one of a loopback backend, a Scryer account or web search; a Scryer row has no key or resources and only Scryer's tools (lib/openclaw-scryer-tools.nix); a web search row has no key or resources and only web_search.";
              }) cfg.mcpRoutes
            ) names
          )
          ++ lib.mapAttrsToList (name: cfg: {
            assertion =
              lib.length (
                lib.filter (v: v != null) [
                  cfg.mcpTools
                  cfg.scryerPasswordFile
                  cfg.webSearchKeyFile
                ]
              ) <= 1;
            message = "${name}: Native and filtered MCP modes are mutually exclusive.";
          }) names
          ++ [
            {
              assertion = tailscale.oauthClientIdFile != null && tailscale.oauthSecretFile != null;
              message = "Tailnet names join with the fleet OAuth client, which is not configured.";
            }
          ];

        users.users.tsnet-proxy = {
          isSystemUser = true;
          group = "tsnet-proxy";
        };
        users.groups.tsnet-proxy = { };

        systemd.services = lib.mapAttrs' (
          name: cfg:
          let
            routed = cfg.mcpRouting.enable;
            package =
              if routed then
                inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.ai-mcp-tsnet-proxy
              else
                proxy;
            table = routeTable name cfg;
            credentialRows = lib.filterAttrs (_: row: rowCredential row != null) cfg.mcpRoutes;
          in
          lib.nameValuePair "tsnet-proxy-${name}" {
            inherit (cfg) description;
            wantedBy = [ "multi-user.target" ];
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ] ++ cfg.after;
            unitConfig.RequiresMountsFor = [ (directory name) ];
            serviceConfig = {
              User = "tsnet-proxy";
              Group = "tsnet-proxy";
              StateDirectory = baseNameOf (directory name);
              StateDirectoryMode = "0700";
              UMask = "0077";
              # systemd reads the root-only secrets and hands this unit a copy.
              LoadCredential = [
                "oauth-id:${tailscale.oauthClientIdFile}"
                "oauth-secret:${tailscale.oauthSecretFile}"
              ]
              ++ lib.optional (cfg.scryerPasswordFile != null) "scryer-password:${cfg.scryerPasswordFile}"
              ++ lib.optional (cfg.webSearchKeyFile != null) "websearch-key:${cfg.webSearchKeyFile}"
              ++ lib.mapAttrsToList (tool: row: "mcp-${tool}:${rowCredential row}") credentialRows;
              ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${state name}";
              ExecStart =
                "${package}/bin/tsnet-proxy -hostname ${name} -state ${state name}"
                + " -backend ${cfg.backend} -port 443"
                + lib.optionalString routed " -mcp-table /etc/tsnet-proxy-${name}-mcp.json"
                + " -oauth-id-file %d/oauth-id -oauth-secret-file %d/oauth-secret"
                + " -tags ${lib.escapeShellArg (lib.concatStringsSep "," cfg.tags)}"
                + lib.optionalString (
                  cfg.mcpTools != null
                ) " -mcp-tools ${lib.escapeShellArg (lib.concatStringsSep "," cfg.mcpTools)}"
                + lib.optionalString (
                  cfg.mcpAllowedNodeIds != [ ]
                ) " -mcp-allowed-node-ids ${lib.escapeShellArg (lib.concatStringsSep "," cfg.mcpAllowedNodeIds)}"
                + lib.optionalString (
                  cfg.mcpResources != [ ]
                ) " -mcp-resources ${lib.escapeShellArg (lib.concatStringsSep "," cfg.mcpResources)}"
                +
                  lib.optionalString (cfg.scryerPasswordFile != null)
                    " -scryer-password-file %d/scryer-password -scryer-username ${lib.escapeShellArg cfg.scryerUsername}"
                + lib.optionalString (
                  cfg.webSearchKeyFile != null
                ) " -websearch-key-file %d/websearch-key -websearch-model ${lib.escapeShellArg cfg.webSearchModel}";
              Restart = "always";
              RestartSec = "30s";
              NoNewPrivileges = true;
              ProtectSystem = "strict";
              ProtectHome = true;
              PrivateTmp = true;
              PrivateDevices = true;
              ProtectHostname = true;
              ProtectClock = true;
              ProtectKernelTunables = true;
              ProtectKernelModules = true;
              ProtectKernelLogs = true;
              ProtectControlGroups = true;
              RestrictAddressFamilies = [
                "AF_UNIX"
                "AF_INET"
                "AF_INET6"
                "AF_NETLINK"
              ];
              RestrictNamespaces = true;
              LockPersonality = true;
              MemoryDenyWriteExecute = true;
              RestrictRealtime = true;
              RestrictSUIDSGID = true;
              RemoveIPC = true;
            }
            // lib.optionalAttrs routed {
              ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
            }
            // lib.optionalAttrs (credentialRows != { }) {
              # A missing source must not stop the front door. With a default,
              # systemd starts the unit anyway (systemd.exec: not fatal). This
              # non-secret text holds a space, so the router refuses it as a
              # Bearer, rejects the table and serves no MCP rows. An empty value
              # does not work: a unit file with "ID:" still fails with 243.
              SetCredential = lib.mapAttrsToList (tool: _: "mcp-${tool}:unavailable credential") credentialRows;
            };
            # The table is deliberately absent from ExecStart and restartTriggers.
            # NixOS switches /etc first, then reloads this unit on table changes.
            reloadTriggers = lib.optionals routed [ table ];
          }
        ) names;
        environment.etc = lib.mapAttrs' (
          name: cfg:
          lib.nameValuePair "tsnet-proxy-${name}-mcp.json" {
            source = routeTable name cfg;
          }
        ) (lib.filterAttrs (_: cfg: cfg.mcpRouting.enable) names);
      };
    };
}
