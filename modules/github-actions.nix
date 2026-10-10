# One trusted, manual Forgerie pilot. This is not a 30-repository worker pool.
{
  perSystem =
    { pkgs, lib, ... }:
    let
      fixture =
        enable:
        (import "${pkgs.path}/nixos/lib/eval-config.nix" {
          system = pkgs.stdenv.hostPlatform.system;
          modules = [
            (import ./github-actions.nix).nixos.modules.base
            {
              mountainous.features.github-actions.enable = enable;
              services.github-runners.forgerie = lib.mkIf enable {
                githubApp = {
                  id = 123456;
                  login = "forgerie";
                  privateKeyFile = "/run/secrets/github-actions-forgerie-app-key";
                };
              };
              system.stateVersion = "25.11";
            }
          ];
        }).config;
      report = import ../tests/github-actions-contract.nix {
        inherit lib;
        enabled = fixture true;
        disabled = fixture false;
      };
    in
    {
      checks.github-actions-contract =
        pkgs.runCommand "github-actions-contract"
          {
            report = builtins.toJSON report;
          }
          ''
            printf '%s\n' "$report" > "$out"
          '';
      checks.github-actions-isolation = pkgs.testers.runNixOSTest (
        import ../tests/github-actions-isolation.nix
      );
      checks.github-actions-preflight =
        pkgs.runCommand "github-actions-preflight-tests"
          {
            nativeBuildInputs = [
              pkgs.python3
              pkgs.openssl
            ];
            GITHUB_ACTIONS_PREFLIGHT_SOURCE = ./github-actions-preflight.py;
            GITHUB_ACTIONS_READY_SOURCE = ./github-actions-ready.py;
          }
          ''
            python3 ${../tests/test_github_actions_preflight.py} > "$out" 2>&1
            python3 ${../tests/test_github_actions_ready.py} >> "$out" 2>&1
          '';
    };

  nixos.modules.base =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.mountainous.features.github-actions;
      runner = config.services.github-runners.forgerie;
      user = "github-runner-forgerie";
      work = "/srv/github-actions/work/forgerie";
      scratch = "/srv/github-actions/tmp/forgerie";
      app = runner.githubApp;
      appId = if app == null then 0 else app.id;
      key =
        if app == null then "/run/secrets/github-actions-forgerie-app-key" else toString app.privateKeyFile;
      prepare = pkgs.writeShellScript "github-actions-prepare" ''
        set -euo pipefail
        # The parents stay root-owned. The runner cannot replace a cleanup root
        # with a symlink and make the privileged cleanup traverse another tree.
        # Runner.Listener enumerates every ancestor before starting. Its group
        # can read/traverse these parents, but cannot write or replace children.
        install -d -m 0750 -o root -g ${user} /srv/github-actions /srv/github-actions/work /srv/github-actions/tmp
        install -d -m 0700 -o ${user} -g ${user} ${work} ${scratch}
        find ${scratch} -mindepth 1 -delete
        find /var/log/github-runner/forgerie -type f -mtime +7 -delete
      '';
      resolvers = pkgs.writeText "github-actions-resolv.conf" ''
        nameserver 1.1.1.1
        nameserver 9.9.9.9
      '';
    in
    {
      options.mountainous.features.github-actions.enable =
        lib.mkEnableOption "restricted native Forgerie GitHub Actions pilot";

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = runner.githubApp != null && runner.tokenFile == null;
            message = "The native pilot requires a dedicated GitHub App, not a PAT or one-hour registration token.";
          }
          {
            assertion =
              runner.url == "https://github.com/forgerie" && runner.runnerGroup == "unzen-forgerie-manual";
            message = "The public Forgerie pilot must register with the restricted organization group, never a repository or default group.";
          }
          {
            assertion = runner.count == 1 && runner.orgs == { } && runner.ephemeral;
            message = "The pilot permits exactly one ephemeral runner.";
          }
          {
            assertion =
              runner.user == user
              && runner.group == user
              && !(builtins.elem "wheel" config.users.users.${user}.extraGroups)
              && !(builtins.elem user config.nix.settings.trusted-users);
            message = "The CI identity must remain an unprivileged, non-wheel, Nix-untrusted user.";
          }
          {
            assertion = lib.hasPrefix "/run/secrets/" key;
            message = "The runner's root-only App key must be deployed under /run/secrets, never the Nix store.";
          }
        ];

        users.groups.${user} = { };
        users.users.${user} = {
          isSystemUser = true;
          group = user;
          home = work;
        };

        # Bind-mount sources must exist before systemd starts any ExecStartPre.
        systemd.tmpfiles.rules = [
          "d /srv/github-actions 0750 root ${user} -"
          "d /srv/github-actions/work 0750 root ${user} -"
          "d /srv/github-actions/tmp 0750 root ${user} -"
          "d ${work} 0700 ${user} ${user} -"
          "d ${scratch} 0700 ${user} ${user} -"
        ];

        # A fixed retry delay bounds traffic without exhausting recovery during
        # a GitHub outage. Explicit systemctl stop still stops the service.
        systemd.services.github-runner-forgerie.unitConfig.StartLimitIntervalSec = lib.mkDefault 0;
        # On-demand status, not another manager or a background polling service.
        environment.etc."github-actions/ready" = {
          mode = "0700";
          source = pkgs.writeShellScript "github-actions-ready" ''
            export PATH=${lib.makeBinPath [ pkgs.openssl pkgs.systemd ]}
            exec ${pkgs.python3}/bin/python3 ${./github-actions-ready.py} \
              --policy-script ${./github-actions-preflight.py} \
              --app-id ${toString appId} --private-key ${lib.escapeShellArg key} "$@"
          '';
        };

        systemd.slices.github-actions.sliceConfig = {
          CPUQuota = lib.mkDefault "400%";
          MemoryHigh = lib.mkDefault "12G";
          MemoryMax = lib.mkDefault "16G";
          TasksMax = lib.mkDefault 2048;
          IOWeight = lib.mkDefault 100;
        };

        services.github-runners.forgerie = {
          enable = lib.mkDefault true;
          name = lib.mkDefault "unzen-forgerie";
          url = lib.mkDefault "https://github.com/forgerie";
          runnerGroup = lib.mkDefault "unzen-forgerie-manual";
          count = lib.mkDefault 1;
          ephemeral = lib.mkDefault true;
          noDefaultLabels = lib.mkDefault true;
          extraLabels = lib.mkDefault [ "unzen-forgerie" ];
          user = lib.mkDefault user;
          group = lib.mkDefault user;
          workDir = lib.mkDefault work;
          extraPackages = with pkgs; [
            nodejs_24
            curl
            jq
            openssl
            python3
            util-linux
          ];
          extraEnvironment = {
            TMPDIR = scratch;
            TMP = scratch;
            TEMP = scratch;
          };
          serviceOverrides = {
            Slice = "github-actions.slice";
            Nice = lib.mkDefault 10;
            # Upstream's on-success policy cannot recover an ExecStartPre
            # registration failure while an old GitHub heartbeat stays online.
            Restart = lib.mkForce "always";
            RestartSec = lib.mkDefault "30s";
            TimeoutStartSec = lib.mkDefault "180s";
            TimeoutStopSec = lib.mkDefault "60s";
            # Replace PrivateTmp's host-tmpfs backing with private disk binds.
            # Both /tmp and /var/tmp stay job-local even if a program ignores TMPDIR.
            PrivateTmp = lib.mkForce false;
            BindPaths = [
              scratch
              "${scratch}:/tmp"
              "${scratch}:/var/tmp"
            ];
            LogsDirectoryMode = "0700";
            BindReadOnlyPaths = [ "${resolvers}:/etc/resolv.conf" ];
            # Nix tools are prebuilt in the OS closure, which roots them for GC.
            # Blocking daemon access keeps all job work inside the CI slice.
            # Actual Nix builds need a separately approved daemon resource policy.
            InaccessiblePaths = [
              "-/nix/var/nix/daemon-socket"
              "-/run/nix-daemon"
              "-/run/tailscale"
            ];
            # Loopback remains available for Forgerie's HTTP contract tests.
            # This is a native trusted-code service, not a VM isolation boundary.
            IPAddressDeny = [
              "10.0.0.0/8"
              "172.16.0.0/12"
              "192.168.0.0/16"
              "100.64.0.0/10"
              "169.254.0.0/16"
              "fc00::/7"
              "fe80::/10"
            ];
            ExecStartPre = lib.mkBefore [
              "+${prepare}"
              "+${pkgs.python3}/bin/python3 ${./github-actions-preflight.py} --app-id ${toString appId} --private-key ${lib.escapeShellArg key}"
            ];
          };
        };
      };
    };
}
