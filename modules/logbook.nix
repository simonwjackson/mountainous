# NixOS owns storage and units; the application profile is deployed from Unzen.
{
  config,
  inputs,
  lib,
  self,
  ...
}:
let
  fleet = config.mountainous.fleetSync;
in
{
  # PHONE PLACEHOLDERS: copy the existing phone identity and full MagicDNS name.
  # These are checked only on hosts in enabled folders that use this peer.
  mountainous.fleetSync.externalDevices.phone = {
    deviceId = null;
    tailnetName = null;
  };
  mountainous.fleetSync.folders.gadgetbridge = {
    enable = lib.mkDefault false;
    hosts = [
      "rakku"
      "phone"
    ];
    files = [ "Gadgetbridge.db" ];
  };

  perSystem = { pkgs, ... }: {
    checks.logbook =
      assert import ../tests/logbook-enabled.nix { inherit inputs lib; };
      assert (
        import ../tests/logbook-contract.nix {
          rakku = self.nixosConfigurations.rakku.config;
          inherit lib;
        }
      );
      pkgs.runCommand "logbook-contract" { nativeBuildInputs = [ pkgs.python3 ]; } ''
        python3 ${../.}/tests/test_logbook_export.py
        touch $out
      '';
  };

  nixos.modules.logbook =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      state = "/var/lib/logbook";
      profile = "/nix/var/nix/profiles/per-user/logbook/application";
      destination = "${state}/inbox/gadgetbridge/Gadgetbridge.db";
      source = "${config.users.users.simon.home}/.local/share/fleet-sync/gadgetbridge/Gadgetbridge.db";
      syncEnabled = fleet.folders.gadgetbridge.enable;
      # Logbook's Oura OAuth app. The client ID is public; the secret is the
      # host's `oura-api-key` sops secret, rendered into the client file.
      ouraClient = config.sops.secrets ? oura-api-key;
      ouraClientFile = config.sops.templates."logbook-oura-client.json".path;
      # Logbook's own Withings app (not Coach's: Withings rotates refresh tokens).
      withingsClient = config.sops.secrets ? withings-api-key;
      withingsClientFile = config.sops.templates."logbook-withings-client.json".path;
      # Registered on both vendor apps. The server completes grants here itself.
      callback = "https://logbook.hummingbird-lake.ts.net/oauth/callback";
      controller = pkgs.writeShellApplication {
        name = "logbook-service-control";
        runtimeInputs = [ pkgs.systemd ];
        text = ''
          if [[ $# != 1 ]]; then exit 2; fi
          case "$1" in
            stop) systemctl stop logbook-tsnet.service logbook.service ;;
            start) systemctl start logbook.service logbook-tsnet.service ;;
            *) echo 'Expected start or stop' >&2; exit 2 ;;
          esac
        '';
      };
      common = {
        User = "logbook";
        Group = "logbook";
        WorkingDirectory = state;
        UMask = "0077";
        Restart = "on-failure";
        RestartSec = 3;
        TimeoutStopSec = 30;
        StateDirectory = "logbook";
        StateDirectoryMode = "0700";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ state ];
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        CapabilityBoundingSet = "";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
          "AF_NETLINK"
        ];
      };
      unit = {
        environment.HOME = state;
        unitConfig.ConditionPathExists = "${profile}/bin/logbook-server";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
      };
    in
    {
      users.groups.logbook = { };
      users.users.logbook = {
        isSystemUser = true;
        group = "logbook";
        home = state;
        createHome = true;
        homeMode = "0700";
        shell = pkgs.bashInteractive;
        hashedPassword = "*";
        openssh.authorizedKeys.keys = [ "restrict ${config.mountainous.appDeployment.deployPublicKey}" ];
      };
      # Reuse Unzen's existing signing trust. No Nix trusted-user access.
      environment.systemPackages = [ controller ];
      security.sudo.extraRules = [
        {
          users = [ "logbook" ];
          commands =
            map
              (action: {
                command = "${controller}/bin/logbook-service-control ${action}";
                options = [ "NOPASSWD" ];
              })
              [
                "start"
                "stop"
              ];
        }
      ];
      environment.persistence."/tundra/permafrost".directories = [
        {
          directory = state;
          user = "logbook";
          group = "logbook";
          mode = "0700";
        }
      ];
      systemd.tmpfiles.rules = [
        "d /nix/var/nix/profiles/per-user/logbook 0755 logbook logbook -"
        "L ${state}/.nix-profile - logbook logbook - ${profile}"
        "d ${state}/data 0700 logbook logbook -"
        "d ${state}/state 0700 logbook logbook -"
        "d ${state}/state/tsnet 0700 logbook logbook -"
        "d ${state}/inbox 0700 logbook logbook -"
        "d ${state}/inbox/gadgetbridge 0750 root logbook -"
      ];
      sops.templates."logbook-oura-client.json" = lib.mkIf ouraClient {
        owner = "logbook";
        mode = "0400";
        restartUnits = [ "logbook.service" ];
        content = builtins.toJSON {
          clientId = "fb234ed4-ab17-4016-bbf5-319dc8cd381b";
          clientSecret = config.sops.placeholder.oura-api-key;
          redirectUri = callback;
        };
      };
      sops.templates."logbook-withings-client.json" = lib.mkIf withingsClient {
        owner = "logbook";
        mode = "0400";
        restartUnits = [ "logbook.service" ];
        content = builtins.toJSON {
          clientId = "1cdf1b07de793c68c55d8a1b007eb0fcd75298d548214e621764d8106e9473af";
          clientSecret = config.sops.placeholder.withings-api-key;
          redirectUri = callback;
        };
      };
      systemd.services.logbook = unit // {
        description = "Logbook loopback life-data core";
        serviceConfig = common // {
          ExecStart =
            "${profile}/bin/logbook-server --port 3160 --data-dir ${state}/data --state-dir ${state}/state --inbox-dir ${state}/inbox --gadgetbridge-export ${destination}"
            + lib.optionalString ouraClient " --oura-client-file ${ouraClientFile}"
            + lib.optionalString withingsClient " --withings-client-file ${withingsClientFile}";
          # The server's graceful shutdown handler listens for Ctrl-C/SIGINT.
          KillSignal = "SIGINT";
          # Only the root bridge publishes snapshots. The server is read-only.
          # "-": a missing directory must not stop the core (first activation
          # can mount persistent state over the tmpfiles-created directory).
          ReadOnlyPaths = [ "-${state}/inbox/gadgetbridge" ];
        };
      };
      systemd.services.logbook-tsnet = unit // {
        description = "Logbook dedicated tailnet node";
        wants = [
          "network-online.target"
          "logbook.service"
        ];
        after = [
          "network-online.target"
          "logbook.service"
        ];
        serviceConfig = common // {
          ExecStart = "${profile}/bin/logbook-tsnet --hostname logbook --state-dir ${state}/state/tsnet --upstream http://127.0.0.1:3160";
          # The sidecar must not write the data directory or inbox.
          StateDirectory = "logbook/state/tsnet";
          ReadOnlyPaths = [ state ];
          ReadWritePaths = [ "${state}/state/tsnet" ];
        };
      };
      systemd.paths.logbook-gadgetbridge = lib.mkIf syncEnabled {
        wantedBy = [ "multi-user.target" ];
        pathConfig = {
          PathChanged = source;
          Unit = "logbook-gadgetbridge.service";
        };
      };
      systemd.services.logbook-gadgetbridge = lib.mkIf syncEnabled {
        description = "Publish only a complete Gadgetbridge export into Logbook's inbox";
        wantedBy = [ "multi-user.target" ];
        after = [ "systemd-tmpfiles-setup.service" ];
        unitConfig.StartLimitIntervalSec = 0;
        serviceConfig = {
          Type = "oneshot";
          User = "root";
          UMask = "0077";
          ExecStart = "${pkgs.python3}/bin/python3 ${./logbook-export.py} ${source} ${destination}";
          Restart = "on-failure";
          RestartSec = 30;
          TimeoutStartSec = 120;
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ReadOnlyPaths = [ "${config.users.users.simon.home}" ];
          ReadWritePaths = [ "${state}/inbox/gadgetbridge" ];
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          CapabilityBoundingSet = [
            "CAP_DAC_READ_SEARCH"
            "CAP_CHOWN"
            "CAP_FOWNER"
          ];
          RestrictAddressFamilies = [ "AF_UNIX" ];
        };
      };
    };
}
