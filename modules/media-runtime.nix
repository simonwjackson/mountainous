# Placement-driven data access and a host-owned VPN. No live credentials in Nix.
{ inputs, ... }:
{
  nixos.modules.media-runtime =
    {
      config,
      lib,
      pkgs,
      utils,
      ...
    }:
    let
      cfg = config.mountainous.features.media-runtime;
      placement = config.mountainous.features.media-applications.placement;
      host = config.networking.hostName;
      applications = config.mountainous.features.media-applications;
      local = name: placement.${name} == host;
      active =
        name:
        local name
        && (name != "nzbget" || applications.usenet != "nzbfast")
        && (name != "nzbfast" || applications.usenet != "nzbget");
      downloaders = [
        "nzbget"
        "transmission"
      ];
      vpnApps = [
        "nzbfast"
        "nzbget"
        "transmission"
        "prowlarr"
      ];
      arr = [
        "sonarr"
        "radarr"
      ];
      hasVpn = lib.any active vpnApps;
      # The host's name-service cache (nscd) runs outside the VPN namespace.
      # A namespaced process that can reach its socket has every hostname
      # resolved by the host, over the host's network: a DNS leak. VPN
      # consumers therefore cannot see the socket, and glibc loads the NSS
      # modules it would otherwise reach through nscd from this directory.
      # They come from the same nixpkgs pin, and glibc, as the applications.
      vpnNssModules = pkgs.runCommand "media-vpn-nss-modules" { } ''
        mkdir -p "$out"
        for module in ${
          (import inputs.nixpkgs-media { system = pkgs.stdenv.hostPlatform.system; }).systemd
        }/lib/libnss_*.so.2; do
          ln -s "$module" "$out/"
        done
      '';
      hasArr = lib.any local arr;
      isLibraryHost = cfg.libraryHost == host;
      hasLibraryAccess = hasArr || isLibraryHost;
      libraryCode = pkgs.runCommand "media-library-runtime" { } ''
        mkdir -p "$out/lib"
        cp ${./media-library-mover.py} "$out/lib/media-library-mover.py"
        cp ${./media-library-cleanup.py} "$out/lib/media-library-cleanup.py"
      '';
      libraryMounts = [
        "/net/mountainous/zao/media"
        "/srv/media-library-view/movies"
        "/srv/media-library-view/tv"
      ];
      mediaRoot = "/srv/basin/media";
      accessRoot = "/srv/media-access";
      completed =
        name: "/srv/basin/downloads/${if name == "nzbget" then "usenet" else "torrents"}/completed";
      share = name: ".downloads/${if name == "nzbget" then "usenet" else "torrents"}";
      fqdn = name: "${name}.${cfg.tailDomain}";
      clients = lib.unique (map fqdn ([ cfg.libraryServer ] ++ map (name: placement.${name}) arr));
      exportClients = lib.concatMapStringsSep " " (
        client:
        # Squashing every caller to root breaks FUSE owner checks after creation.
        # Placement participants use the same application UIDs and media GID.
        "${client}(rw,fsid=0,crossmnt,no_subtree_check,no_root_squash)"
      ) clients;
      vpn = pkgs.writeShellApplication {
        name = "media-vpn";
        runtimeInputs = with pkgs; [
          wireguard-tools
          iproute2
          curl
          gnugrep
          gnused
          coreutils
          procps
          iptables
          util-linux
          glibc.getent
          iputils
          systemd
          gawk
        ];
        text = builtins.readFile ./media-vpn.sh;
      };
      remoteDownloads = lib.filter (name: !local name && hasArr) downloaders;
      localDownloads = lib.filter local downloaders;
      exportedLibrary = lib.optionals isLibraryHost [
        "movies"
        "tv"
      ];
      mandatory =
        lib.optionals hasArr [
          "/srv/range/media/movies"
          "/srv/range/media/tv"
        ]
        ++ lib.optionals hasLibraryAccess libraryMounts
        ++ map completed (lib.optionals hasArr downloaders);
      rootDirectories = [
        accessRoot
        "${accessRoot}/.downloads"
        mediaRoot
        "${mediaRoot}/movies"
        "${mediaRoot}/tv"
        "/srv/range/media/movies"
        "/srv/range/media/tv"
        "/net/mountainous/zao/media"
        "/srv/media-library-view/movies"
        "/srv/media-library-view/tv"
      ]
      ++ lib.concatMap (
        name:
        let
          root = "/srv/basin/downloads/${if name == "nzbget" then "usenet" else "torrents"}";
        in
        [
          root
          (completed name)
        ]
        ++ lib.optionals (local name) (
          map (part: "${root}/${part}") (
            if name == "nzbget" then
              [
                "incoming"
                "intermediate"
                "failed"
                "queue"
                "tmp"
                "scripts"
              ]
            else
              [
                "incomplete"
                "watch"
              ]
          )
        )
      ) downloaders
      ++ lib.optionals (active "nzbfast") [
        "/srv/basin/downloads/usenet/nzbfast/Series"
        "/srv/basin/downloads/usenet/nzbfast/Movies"
      ];
    in
    {
      options.mountainous.features.media-runtime = {
        enable = lib.mkEnableOption "portable media storage and VPN runtime";
        libraryHost = lib.mkOption {
          type = lib.types.str;
          default = "unzen";
        };
        libraryServer = lib.mkOption {
          type = lib.types.str;
          default = "zao";
        };
        libraryOwnerUid = lib.mkOption {
          type = lib.types.ints.unsigned;
          default = 0;
          description = "Stored UID for new files created through the view. Existing stored ownership remains unchanged.";
        };
        libraryMediaGid = lib.mkOption {
          type = lib.types.ints.positive;
          default = 993;
          description = "Stored library media GID translated only in the client-side view.";
        };
        tailDomain = lib.mkOption {
          type = lib.types.str;
          default = "hummingbird-lake.ts.net";
        };
        libraryMover = {
          enable = lib.mkEnableOption "verified local-import handoff to the mapped media library";
          minAgeMinutes = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 60;
          };
          minFreePercent = lib.mkOption {
            type = lib.types.ints.between 0 100;
            default = 20;
          };
          nightlySchedule = lib.mkOption {
            type = lib.types.str;
            default = "*-*-* 03:00:00 America/Denver";
          };
          refreshConfigFile = lib.mkOption {
            type = lib.types.str;
            default = "/var/lib/media-migration/credentials/library-refresh.json";
            description = "Protected existing Jellyfin connection used after a verified batch; no enrollment or password change.";
          };
        };
        vpnConfigFile = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/media-migration/credentials/wireguard.conf";
        };
      };
      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.mountainous.features.media-applications.enable;
            message = "Media runtime requires the gated media application layer.";
          }
        ];
        boot.kernel.sysctl."net.ipv4.ip_forward" = lib.mkIf hasVpn 1;
        networking.firewall.trustedInterfaces = lib.optional hasVpn "veth-vpn-host";
        networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 2049 ];
        environment.etc."media-vpn-leak-audit.json".text = builtins.toJSON {
          vpnUnits = map (name: "${name}.service") (lib.filter active vpnApps);
        };
        environment.systemPackages = [
          pkgs.nfs-utils
          pkgs.mergerfs
          pkgs.bindfs
        ];
        systemd.tmpfiles.rules =
          map (directory: "d ${directory} 2775 root media -") rootDirectories
          # Upstream creates this root with d/2770. z adjusts only the root,
          # not existing payload ownership, and avoids duplicate d rules.
          ++ lib.optional (active "nzbfast") "z /srv/basin/downloads/usenet/nzbfast 2775 root media -"
          ++ map (part: "d ${accessRoot}/${part} 2775 root media -") (
            exportedLibrary ++ map share localDownloads
          )
          ++ lib.optional (
            isLibraryHost && cfg.libraryMover.enable
          ) "d /var/lib/media-migration/library-handoff 0700 root root -";
        services.nfs.server = lib.mkIf (isLibraryHost || localDownloads != [ ]) {
          enable = true;
          exports = "${accessRoot} ${exportClients}\n";
        };
        fileSystems = import ../lib/media-storage-layout.nix {
          inherit lib host placement;
          inherit (cfg)
            libraryHost
            libraryServer
            tailDomain
            libraryOwnerUid
            libraryMediaGid
            ;
          mediaGid = config.users.groups.media.gid;
          libraryUsers = {
            movies = config.ids.uids.radarr;
            tv = config.ids.uids.sonarr;
          };
        };
        systemd.timers = lib.mkIf (isLibraryHost && cfg.libraryMover.enable) (
          lib.genAttrs [ "media-library-mover-nightly" "media-library-mover-low-space" ] (name: {
            wantedBy = lib.optionals (config.mountainous.features.media-applications.processing == "enabled") [
              "timers.target"
            ];
            timerConfig =
              if name == "media-library-mover-nightly" then
                {
                  Unit = "media-library-mover@nightly.service";
                  OnCalendar = cfg.libraryMover.nightlySchedule;
                  Persistent = true;
                }
              else
                {
                  Unit = "media-library-mover@low-space.service";
                  OnBootSec = "5min";
                  OnUnitActiveSec = "5min";
                  RandomizedDelaySec = "30s";
                };
          })
        );
        systemd.services = lib.mkMerge [
          {
            nfs-server = lib.mkIf (isLibraryHost || localDownloads != [ ]) {
              after = [ "systemd-tmpfiles-setup.service" ];
              unitConfig.RequiresMountsFor = map (part: "${accessRoot}/${part}") (
                exportedLibrary ++ map share localDownloads
              );
            };
            media-storage-ready = {
              after = [ "local-fs.target" ];
              unitConfig.RequiresMountsFor = mandatory;
              # Local staging is an ordinary directory. RequiresMountsFor
              # follows its backing filesystem; only managed mounts have units.
              bindsTo = map (directory: "${utils.escapeSystemdPath directory}.mount") (
                lib.filter (directory: !(lib.elem directory (map completed localDownloads))) mandatory
              );
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
              path = [
                pkgs.util-linux
                pkgs.coreutils
              ];
              script =
                lib.concatMapStringsSep "\n"
                  (directory: ''
                    mountpoint -q ${lib.escapeShellArg directory}
                    test -d ${lib.escapeShellArg directory}
                  '')
                  (
                    lib.optionals hasLibraryAccess libraryMounts
                    ++ lib.optionals hasArr [
                      "/srv/range/media/movies"
                      "/srv/range/media/tv"
                    ]
                    ++ map completed remoteDownloads
                  );
            };
            "media-library-mover@" = lib.mkIf (isLibraryHost && cfg.libraryMover.enable) {
              description = "Verified local-import handoff to the mapped library (%i)";
              requires = [ "media-storage-ready.service" ];
              after = [ "media-storage-ready.service" ];
              bindsTo = map (directory: "${utils.escapeSystemdPath directory}.mount") libraryMounts;
              unitConfig.ConditionPathExists = [
                "/var/lib/media-migration/ready/library-mover"
                cfg.libraryMover.refreshConfigFile
              ];
              serviceConfig = {
                Type = "oneshot";
                ExecStart = "${pkgs.python3}/bin/python3 ${libraryCode}/lib/media-library-mover.py ${mediaRoot} /srv/media-library-view --mode %i --min-age-seconds ${
                  toString (cfg.libraryMover.minAgeMinutes * 60)
                } --min-free-percent ${toString cfg.libraryMover.minFreePercent} --refresh-config ${cfg.libraryMover.refreshConfigFile}";
                UMask = "0002";
                Nice = 19;
                IOSchedulingClass = "idle";
                ProtectSystem = "strict";
                ProtectHome = true;
                PrivateTmp = true;
                RuntimeDirectory = "media-library-mover";
                NoNewPrivileges = true;
                ReadWritePaths = [
                  mediaRoot
                  "/srv/media-library-view"
                  "/var/lib/media-migration/library-handoff"
                ];
                TimeoutStartSec = "6h";
              };
            };
            media-vpn = lib.mkIf hasVpn {
              description = "Preserved WireGuard downloader namespace";
              wantedBy = [ "multi-user.target" ];
              # Re-establish admitted local consumers after a tunnel restart.
              # Their existing state/processing/readiness gates still apply.
              wants = [ "network-online.target" ] ++ map (name: "${name}.service") (lib.filter active vpnApps);
              after = [ "network-online.target" ];
              before = map (name: "${name}.service") (lib.filter active vpnApps);
              unitConfig.ConditionPathExists = [
                "/var/lib/media-migration/ready/vpn"
                cfg.vpnConfigFile
              ];
              environment = {
                VPN_NS_CONFIG = cfg.vpnConfigFile;
                VPN_NS_LOCAL_NETS = "100.64.0.0/10";
                VPN_NS_TAILSCALE_HOSTS = lib.concatMapStringsSep " " fqdn [
                  "tv"
                  "movies"
                  "indexers"
                  "usenet"
                  "torrents"
                  cfg.libraryServer
                ];
              };
              serviceConfig = {
                Type = "notify";
                NotifyAccess = "all";
                ExecStart = "${vpn}/bin/media-vpn --setup";
                ExecStop = "${vpn}/bin/media-vpn --cleanup";
                Restart = "on-failure";
                RestartSec = "30s";
              };
            };
          }
          (lib.genAttrs (lib.filter active vpnApps) (_: {
            after = [ "media-vpn.service" ];
            bindsTo = [ "media-vpn.service" ];
            requires = [ "media-vpn.service" ];
            serviceConfig = {
              NetworkNamespacePath = "/run/netns/vpn";
              BindReadOnlyPaths = [
                "/etc/netns/vpn/resolv.conf:/etc/resolv.conf"
                "/etc/netns/vpn/hosts:/etc/hosts"
              ];
              InaccessiblePaths = [ "-/run/nscd" ];
            };
            environment.LD_LIBRARY_PATH = "${vpnNssModules}";
          }))
          (lib.genAttrs (lib.filter local arr) (_: {
            requires = [ "media-storage-ready.service" ];
            after = [ "media-storage-ready.service" ];
            bindsTo = map (directory: "${utils.escapeSystemdPath directory}.mount") [
              "/net/mountainous/zao/media"
              "/srv/media-library-view/movies"
              "/srv/media-library-view/tv"
              "/srv/range/media/movies"
              "/srv/range/media/tv"
            ];
          }))
        ];
      };
    };
}
