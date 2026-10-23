# Beszel host monitoring: one hub on Rakku, an agent on every host.
#
# Agents dial out to the hub over the tailnet with a WebSocket; no host opens a
# port and the agent SSH server is off. The hub's host list is generated from
# `nixos.hosts`, so a host in the flake is a host in the hub. The hub deletes
# any system that config.yml does not list. Renaming a host loses its history.
#
# Agents verify the hub with its fixed SSH key. The private half and every
# agent token live in secrets/beszel/hub.yaml (master + Rakku); each host's
# own token also sits in its secrets/hosts/<host>.yaml.
#
# The first web login creates the admin account. Restart beszel-hub once after
# it: the hub applies config.yml only when an account exists to own the systems. Alert thresholds and the
# notification URL live in the hub's database and are set in its UI. Alerts go
# to `generic://127.0.0.1:8091/beszel?template=json&disabletls=yes`: the
# beszel-notify bridge, which publishes them to the `notify` topic. Beszel only
# sends to loopback for an admin account.
{
  config,
  inputs,
  self,
  ...
}:
let
  hostNames = builtins.attrNames config.nixos.hosts;
  hubPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKhkSuyrf+twVaJAZ2Kc1e03mC0rt3rk98vCX+7bQFJ6 beszel-hub";
  hubName = "beszel";
  tailnet = "hummingbird-lake.ts.net";
  hubPort = 8090;
  bridgePort = 8091;
  agentPort = 45876;
  beszel = pkgs: inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.beszel;
  bridge = ./beszel-notify.py;

  agent =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.mountainous.beszel;
      host = config.networking.hostName;
    in
    {
      options.mountainous.beszel = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Report this host to the Beszel hub.";
        };
        hubUrl = lib.mkOption {
          type = lib.types.str;
          default = "https://${hubName}.${tailnet}";
          description = "Where the agent dials the hub.";
        };
        extraFilesystems = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          # The Towada pool, where a host mounts it.
          default =
            let
              towada = config.mountainous.features.towada or { };
            in
            lib.optional (towada.enable or false) "${towada.mountPoint}__towada";
          defaultText = lib.literalExpression ''[ "<towada mountPoint>__towada" ] when Towada is enabled'';
          example = [ "/srv/lakes/towada__towada" ];
          description = "Mount points or devices to chart besides /. `path__name` sets the label.";
        };
      };

      config = lib.mkIf cfg.enable {
        sops.secrets.beszel-token = {
          sopsFile = ../secrets/hosts/${host}.yaml;
          mode = "0400";
        };
        sops.templates."beszel-agent.env" = {
          content = "TOKEN=${config.sops.placeholder.beszel-token}\n";
          mode = "0400";
          restartUnits = [ "beszel-agent.service" ];
        };
        services.beszel.agent = {
          enable = true;
          package = beszel pkgs;
          smartmon.enable = lib.mkDefault true;
          environmentFile = config.sops.templates."beszel-agent.env".path;
          environment = {
            HUB_URL = cfg.hubUrl;
            KEY = hubPublicKey;
            DISABLE_SSH = "true";
          }
          // lib.optionalAttrs (cfg.extraFilesystems != [ ]) {
            EXTRA_FILESYSTEMS = lib.concatStringsSep "," cfg.extraFilesystems;
          };
        };
      };
    };

  hub =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      dataDir = "/var/lib/beszel-hub";
      data = "${dataDir}/beszel_data";
      secrets = config.sops.secrets;
      hubFile = ../secrets/beszel/hub.yaml;
      tokenSecret = host: "beszel-token-${host}";
      systems = lib.concatMapStrings (host: ''
        - name: ${host}
          host: ${host}
          port: ${toString agentPort}
          token: ${config.sops.placeholder.${tokenSecret host}}
      '') hostNames;
      # Beszel refuses to create a system without an owner, and the first owner
      # is the account made in the web UI. Until it exists, start without
      # config.yml; restart the hub once after the first login.
      stage = pkgs.writeShellScript "beszel-hub-stage" ''
        set -eu
        ${pkgs.coreutils}/bin/install -d -m 0700 ${data}
        ${pkgs.coreutils}/bin/install -m 0600 "$CREDENTIALS_DIRECTORY/hub-key" ${data}/id_ed25519
        users=0
        if [ -e ${data}/data.db ]; then
          users=$(${pkgs.sqlite}/bin/sqlite3 -readonly ${data}/data.db 'SELECT count(*) FROM users' 2>/dev/null || echo 0)
        fi
        if [ "$users" -gt 0 ]; then
          ${pkgs.coreutils}/bin/install -m 0600 "$CREDENTIALS_DIRECTORY/config" ${data}/config.yml
        else
          echo "no Beszel account yet: starting without config.yml" >&2
          ${pkgs.coreutils}/bin/rm -f ${data}/config.yml
        fi
      '';
      notify = self.packages.${pkgs.stdenv.hostPlatform.system}.notify-sync;
    in
    {
      sops.secrets = {
        beszel-hub-key = {
          sopsFile = hubFile;
          mode = "0400";
          restartUnits = [ "beszel-hub.service" ];
        };
        beszel-alerts-token = {
          sopsFile = hubFile;
          mode = "0400";
          restartUnits = [ "beszel-notify.service" ];
        };
      }
      // lib.genAttrs (map tokenSecret hostNames) (_: {
        sopsFile = hubFile;
        mode = "0400";
      });
      sops.templates."beszel-config.yml" = {
        content = "systems:\n" + systems;
        mode = "0400";
        restartUnits = [ "beszel-hub.service" ];
      };

      services.beszel.hub = {
        enable = true;
        package = beszel pkgs;
        host = "127.0.0.1";
        port = hubPort;
        environment.APP_URL = "https://${hubName}.${tailnet}";
      };
      users.groups.beszel-hub = { };
      users.users.beszel-hub = {
        isSystemUser = true;
        group = "beszel-hub";
      };
      systemd.services.beszel-hub = {
        unitConfig.RequiresMountsFor = [ dataDir ];
        serviceConfig = {
          # A stable owner for the persisted database, as ntfy has.
          DynamicUser = lib.mkForce false;
          Group = "beszel-hub";
          LoadCredential = [
            "hub-key:${secrets.beszel-hub-key.path}"
            "config:${config.sops.templates."beszel-config.yml".path}"
          ];
          ExecStartPre = lib.mkBefore [ "${stage}" ];
        };
      };
      # This host's own agent stays off the tailnet path.
      mountainous.beszel.hubUrl = "http://127.0.0.1:${toString hubPort}";
      mountainous.tailnetNames.${hubName} = {
        description = "Beszel hub tailnet proxy";
        backend = "http://127.0.0.1:${toString hubPort}";
        after = [ "beszel-hub.service" ];
      };

      users.groups.beszel-notify = { };
      users.users.beszel-notify = {
        isSystemUser = true;
        group = "beszel-notify";
      };
      systemd.services.beszel-notify = {
        description = "Forward Beszel alerts to the notify topic";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        unitConfig.RequiresMountsFor = [ "/var/lib/beszel-notify" ];
        environment = {
          NOTIFY_URL = config.mountainous.notifications.server;
          NOTIFY_TOKEN_FILE = "%d/token";
          NOTIFY_BUTTON_TOKEN_FILE = "%d/button";
        };
        serviceConfig = {
          ExecStart = lib.escapeShellArgs [
            "${pkgs.python3}/bin/python3"
            "${bridge}"
            "--listen"
            "127.0.0.1:${toString bridgePort}"
            "--state-dir"
            "/var/lib/beszel-notify"
            "--notify"
            "${notify}/bin/notify"
          ];
          LoadCredential = [
            "token:${secrets.beszel-alerts-token.path}"
            "button:${secrets.notify-button-token.path}"
          ];
          User = "beszel-notify";
          Group = "beszel-notify";
          StateDirectory = "beszel-notify";
          StateDirectoryMode = "0700";
          Restart = "always";
          RestartSec = "10s";
          NoNewPrivileges = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          ProtectKernelTunables = true;
          ProtectControlGroups = true;
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
          directory = dataDir;
          user = "beszel-hub";
          group = "beszel-hub";
          mode = "0700";
        }
        {
          directory = "/var/lib/beszel-notify";
          user = "beszel-notify";
          group = "beszel-notify";
          mode = "0700";
        }
      ];
    };
in
{
  perSystem =
    { pkgs, lib, ... }:
    {
      checks = {
        beszel-notify =
          pkgs.runCommand "beszel-notify"
            {
              nativeBuildInputs = [
                pkgs.python3
                pkgs.bash
              ];
            }
            ''
              python3 ${../tests/test_beszel_notify.py} ${bridge}
              touch $out
            '';
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isx86_64 {
        beszel-contract =
          let
            configs = builtins.mapAttrs (_: s: s.config) self.nixosConfigurations;
            hubs = lib.filterAttrs (_: c: c.services.beszel.hub.enable) configs;
            problems =
              lib.concatLists (
                lib.mapAttrsToList (
                  host: c:
                  let
                    env = c.services.beszel.agent.environment;
                  in
                  lib.optional (!c.services.beszel.agent.enable) "${host}: no agent"
                  ++ lib.optional (env.DISABLE_SSH or "" != "true") "${host}: agent SSH server is on"
                  ++ lib.optional (env.KEY or "" != hubPublicKey) "${host}: agent does not pin the hub key"
                  ++ lib.optional (c.services.beszel.agent.openFirewall) "${host}: agent port is open"
                ) (lib.getAttrs hostNames configs)
              )
              ++ lib.optional (builtins.attrNames hubs != [ "rakku" ]) "the hub must run on rakku only"
              ++ (
                let
                  rakku = configs.rakku;
                  persisted = map (d: d.directory) rakku.environment.persistence."/tundra/permafrost".directories;
                  template = rakku.sops.templates."beszel-config.yml".content;
                in
                lib.optional (!(lib.elem "/var/lib/beszel-hub" persisted)) "hub database is not persisted"
                ++ lib.optional (!(lib.elem "/var/lib/beszel-notify" persisted)) "bridge state is not persisted"
                ++ lib.optional (rakku.services.beszel.hub.host != "127.0.0.1") "hub listens beyond loopback"
                ++ lib.optional (
                  rakku.systemd.services.beszel-mcp.environment.MCP_HOST != "127.0.0.1"
                ) "beszel-mcp listens beyond loopback"
                ++ lib.optional (
                  !(lib.hasInfix "MCP_AUTH_TOKEN=" rakku.sops.templates."beszel-mcp.env".content)
                ) "beszel-mcp has no bearer token"
                ++ lib.optional (rakku.systemd.services.beszel-hub.serviceConfig.DynamicUser) "hub uses a dynamic user"
                ++ map (h: "config.yml misses ${h}") (
                  lib.filter (h: !(lib.hasInfix "- name: ${h}\n" template)) hostNames
                )
              );
          in
          if problems == [ ] then
            pkgs.runCommand "beszel-contract" { } "touch $out"
          else
            throw "beszel:\n  ${lib.concatStringsSep "\n  " problems}";
      };
    };

  nixos.modules.base = agent;
  nixos.modules.beszel-hub = hub;
  # Virtual disks report no SMART data.
  nixos.modules.oracle-vm.services.beszel.agent.smartmon.enable = false;
}
