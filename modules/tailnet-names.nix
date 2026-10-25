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
            };
          }
        );
        default = { };
        description = "Tailnet HTTPS names served from this host, keyed by name.";
      };

      config = lib.mkIf (names != { }) {
        assertions = [
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
              ];
              ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${state name}";
              ExecStart =
                "${proxy}/bin/tsnet-proxy -hostname ${name} -state ${state name}"
                + " -backend ${cfg.backend} -port 443"
                + " -oauth-id-file %d/oauth-id -oauth-secret-file %d/oauth-secret"
                + " -tags ${lib.concatStringsSep "," tailscale.tags}";
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
            };
          }
        ) names;
      };
    };
}
