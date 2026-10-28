# Single-user CardDAV. Service state and identity stay together during a
# controlled move; never enable a second placement against a copy of the state.
{ inputs, self, ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    let
      problems = import ../lib/contacts-contract.nix { inherit lib; } self.nixosConfigurations;
    in
    {
      packages.contacts = inputs.contacts.packages.${system}.default;
      checks.contacts =
        assert import ../tests/contacts.nix { inherit lib self; };
        if problems == [ ] then
          pkgs.runCommand "contacts-contract" { } "touch $out"
        else
          throw "contacts:\n  ${lib.concatStringsSep "\n  " problems}";
    };

  nixos.modules.contacts =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.mountainous.features.contacts;
      state = "/var/lib/contacts";
    in
    {
      options.mountainous.features.contacts = {
        enable = lib.mkEnableOption "the single-user contacts CardDAV service";
        package = lib.mkOption {
          type = lib.types.package;
          inherit (inputs.contacts.packages.${pkgs.stdenv.hostPlatform.system}) default;
          description = "The contacts flake's default package.";
        };
        port = lib.mkOption {
          type = lib.types.port;
          default = 8480;
          description = "Loopback HTTP port. Only the tailnet proxy exposes it.";
        };
        listen = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          default = "127.0.0.1:${toString cfg.port}";
        };
        tailnetName = lib.mkOption {
          type = lib.types.str;
          default = "contacts";
        };
        passwordFile = lib.mkOption {
          type = lib.types.path;
          description = "Root-only sops password source, copied with LoadCredential.";
        };
      };

      config = lib.mkIf cfg.enable {
        # A stable system user also permits offline imports while the unit is
        # stopped. Rakku persists /var/lib/nixos, including UID/GID allocation.
        users.groups.contacts = { };
        users.users.contacts = {
          isSystemUser = true;
          group = "contacts";
          home = state;
        };
        environment.systemPackages = [ cfg.package ];
        environment.persistence."/tundra/permafrost".directories = [
          {
            directory = state;
            user = "contacts";
            group = "contacts";
            mode = "0700";
          }
        ];
        mountainous.tailnetNames.${cfg.tailnetName} = {
          description = "Contacts CardDAV tailnet HTTPS proxy";
          backend = "http://${cfg.listen}";
          after = [ "contacts.service" ];
        };
        systemd.services.contacts = {
          description = "Single-user contacts CardDAV server";
          wantedBy = [ "multi-user.target" ];
          unitConfig.RequiresMountsFor = [ state ];
          serviceConfig = {
            User = "contacts";
            Group = "contacts";
            StateDirectory = "contacts";
            StateDirectoryMode = "0700";
            WorkingDirectory = state;
            LoadCredential = [ "contacts-password:${cfg.passwordFile}" ];
            # %d is systemd's $CREDENTIALS_DIRECTORY; no secret enters the store.
            ExecStart = "${lib.getExe cfg.package} serve --listen ${cfg.listen} --data-dir ${state} --username simon --password-file %d/contacts-password";
            UMask = "0077";
            Restart = "on-failure";
            RestartSec = 3;
            # The server's graceful shutdown handler listens for Ctrl-C.
            KillSignal = "SIGINT";
            TimeoutStopSec = 30;
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
            ];
            RestrictNamespaces = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            LockPersonality = true;
            MemoryDenyWriteExecute = true;
            CapabilityBoundingSet = "";
            RemoveIPC = true;
          };
        };
      };
    };
}
