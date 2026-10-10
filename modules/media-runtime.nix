# Placement-driven data access and a host-owned VPN. No live credentials in Nix.
{ ... }:
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
      local = name: placement.${name} == host;
      downloaders = [
        "nzbget"
        "transmission"
      ];
      vpnApps = [
        "nzbget"
        "transmission"
        "prowlarr"
      ];
      arr = [
        "sonarr"
        "radarr"
      ];
      hasVpn = lib.any local vpnApps;
      hasArr = lib.any local arr;
      isLibraryHost = cfg.libraryHost == host;
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
          "/net/mountainous/zao/media"
          "/srv/media-library-view/movies"
          "/srv/media-library-view/tv"
        ]
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
      ) downloaders;
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
        environment.systemPackages = [
          pkgs.nfs-utils
          pkgs.mergerfs
          pkgs.bindfs
        ];
        systemd.tmpfiles.rules =
          map (directory: "d ${directory} 2775 root media -") rootDirectories
          ++ map (part: "d ${accessRoot}/${part} 2775 root media -") (
            exportedLibrary ++ map share localDownloads
          );
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
              bindsTo = map (directory: "${utils.escapeSystemdPath directory}.mount") mandatory;
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
                    lib.optionals hasArr [
                      "/net/mountainous/zao/media"
                      "/srv/media-library-view/movies"
                      "/srv/media-library-view/tv"
                      "/srv/range/media/movies"
                      "/srv/range/media/tv"
                    ]
                    ++ map completed remoteDownloads
                  );
            };
            media-vpn = lib.mkIf hasVpn {
              description = "Preserved WireGuard downloader namespace";
              wantedBy = [ "multi-user.target" ];
              wants = [ "network-online.target" ];
              after = [ "network-online.target" ];
              before = map (name: "${name}.service") (lib.filter local vpnApps);
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
          (lib.genAttrs (lib.filter local vpnApps) (_: {
            after = [ "media-vpn.service" ];
            bindsTo = [ "media-vpn.service" ];
            requires = [ "media-vpn.service" ];
            serviceConfig = {
              NetworkNamespacePath = "/run/netns/vpn";
              BindReadOnlyPaths = [
                "/etc/netns/vpn/resolv.conf:/etc/resolv.conf"
                "/etc/netns/vpn/hosts:/etc/hosts"
              ];
            };
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
