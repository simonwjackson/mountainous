# Valhalla: the routing server Vela asks for car routes (Vela ADR 0004),
# served on the tailnet as https://valhalla.<tailnet>.
#
# nixpkgs packages Valhalla, so no container is needed. Two units:
#   - valhalla-tiles: a oneshot, started by a monthly night timer. It downloads
#     the OpenStreetMap extract, builds the routing tiles at low concurrency,
#     writes one tile tar, checks that it routes, and renames it over the live
#     one (modules/valhalla-tiles.sh).
#   - valhalla: the server. It memory-maps the tile tar (mjolnir.tile_extract)
#     and listens on loopback only. The tailnet name is the only way in.
#
# The first extract does not build itself: start valhalla-tiles once after the
# first deploy. The server waits for the extract to exist.
{ self, ... }:
let
  # The tile builder as a command, so the check runs the code the host runs.
  tilesCommand =
    pkgs:
    pkgs.writeShellApplication {
      name = "valhalla-tiles";
      runtimeInputs = [
        pkgs.valhalla
        pkgs.curl
        pkgs.jq
        pkgs.coreutils
      ];
      text = builtins.readFile ./valhalla-tiles.sh;
    };
in
{
  perSystem =
    { pkgs, lib, ... }:
    let
      problems = lib.concatLists (
        lib.mapAttrsToList (
          host: system:
          let
            c = system.config;
            cfg = c.mountainous.features.valhalla or null;
            want = ok: msg: lib.optional (!ok) "${host}: ${msg}";
            serverConfig = builtins.fromJSON (builtins.readFile cfg.serverConfig);
            # The filesystem that holds a path: the longest mount point above it.
            mountOf =
              path:
              lib.last (
                lib.sort (a: b: lib.stringLength a < lib.stringLength b) (
                  lib.filter (m: m == "/" || path == m || lib.hasPrefix "${m}/" path) (lib.attrNames c.fileSystems)
                )
              );
            dataMount = mountOf cfg.dataDir;
            build = c.systemd.services.valhalla-tiles;
          in
          lib.optionals (cfg != null && cfg.enable) (
            want (
              serverConfig.httpd.service.listen == "tcp://127.0.0.1:${toString cfg.port}"
            ) "the server listens beyond loopback"
            ++ want (
              serverConfig.mjolnir.tile_extract == "${cfg.dataDir}/valhalla_tiles.tar"
            ) "the server does not serve the swapped extract"
            ++ want (
              c.fileSystems.${dataMount}.device != c.fileSystems."/".device
            ) "the tiles are on the root disk (${dataMount})"
            ++ want (cfg.buildConcurrency <= 4) "the tile build uses more than 4 threads"
            ++ want (build.serviceConfig ? MemoryMax) "the tile build has no memory limit"
            ++ want (c.systemd.timers ? valhalla-tiles) "no timer rebuilds the tiles"
            ++ want (c.mountainous.tailnetNames ? valhalla) "no tailnet name"
            ++ want (!(lib.elem cfg.port c.networking.firewall.allowedTCPPorts)) "the server port is open"
          )
        ) self.nixosConfigurations
      );
    in
    {
      checks.valhalla =
        if problems == [ ] then
          pkgs.runCommand "valhalla" { } "touch $out"
        else
          throw "valhalla:\n  ${lib.concatStringsSep "\n  " problems}";

      # The builder end to end on a tiny invented road grid: download, build,
      # smoke route, swap. A second run must keep the first extract as the
      # previous one, and a run with a bad checksum must leave both alone.
      checks.valhalla-tiles =
        pkgs.runCommand "valhalla-tiles"
          {
            nativeBuildInputs = [
              (tilesCommand pkgs)
              pkgs.osmium-tool
              pkgs.coreutils
            ];
          }
          ''
            set -euo pipefail
            mkdir -p mirror data
            osmium cat ${../tests/fixtures/valhalla/grid.osm} -o mirror/grid.osm.pbf
            (cd mirror && md5sum grid.osm.pbf > grid.osm.pbf.md5)
            export VALHALLA_DATA=$PWD/data
            export VALHALLA_PBF_URL=file://$PWD/mirror/grid.osm.pbf
            export VALHALLA_CONCURRENCY=1
            export VALHALLA_SMOKE_REQUEST='{"locations":[{"lat":10.0,"lon":10.0},{"lat":10.01,"lon":10.01}],"costing":"auto"}'

            valhalla-tiles
            test -s data/valhalla_tiles.tar
            test ! -e data/work
            first=$(stat -c %i data/valhalla_tiles.tar)

            valhalla-tiles
            test "$(stat -c %i data/valhalla_tiles.previous.tar)" = "$first"
            second=$(stat -c %i data/valhalla_tiles.tar)
            test "$second" != "$first"

            echo "0000  grid.osm.pbf" > mirror/grid.osm.pbf.md5
            if valhalla-tiles; then
              echo "a bad checksum was accepted" >&2
              exit 1
            fi
            test "$(stat -c %i data/valhalla_tiles.tar)" = "$second"
            test "$(stat -c %i data/valhalla_tiles.previous.tar)" = "$first"
            touch $out
          '';
    };

  nixos.modules.valhalla =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.mountainous.features.valhalla;
      live = "${cfg.dataDir}/valhalla_tiles.tar";
      serverConfig =
        pkgs.runCommand "valhalla-server.json"
          {
            nativeBuildInputs = [
              pkgs.valhalla
              pkgs.jq
            ];
          }
          ''
            valhalla_build_config \
              --mjolnir-tile-extract ${live} \
              --mjolnir-tile-dir ${cfg.dataDir}/no-tile-dir \
              --mjolnir-traffic-extract ${cfg.dataDir}/no-traffic.tar \
              --httpd-service-listen tcp://127.0.0.1:${toString cfg.port} \
              --httpd-service-loopback ipc:///tmp/valhalla-loopback \
              --httpd-service-interrupt ipc:///tmp/valhalla-interrupt |
              jq '.mjolnir.logging.color = false | .logging.color = false' > $out
          '';
    in
    {
      options.mountainous.features.valhalla = {
        enable = lib.mkEnableOption "the Valhalla routing server and its monthly tile build";
        dataDir = lib.mkOption {
          type = lib.types.str;
          example = "/srv/lakes/towada/valhalla";
          description = "Holds the live tile extract and the build's work files. Needs about 80 GB for the whole US. Not the root disk.";
        };
        port = lib.mkOption {
          type = lib.types.port;
          default = 8002;
          description = "Loopback port of the server.";
        };
        extractUrl = lib.mkOption {
          type = lib.types.str;
          default = "https://download.geofabrik.de/north-america/us-latest.osm.pbf";
          description = "The OpenStreetMap extract to build from. Geofabrik publishes <url>.md5 beside it.";
        };
        buildConcurrency = lib.mkOption {
          type = lib.types.ints.positive;
          default = 4;
          description = "mjolnir.concurrency for the tile build. Memory use grows with it.";
        };
        buildMemoryMax = lib.mkOption {
          type = lib.types.str;
          default = "32G";
          description = "Hard memory limit of the tile build.";
        };
        serverThreads = lib.mkOption {
          type = lib.types.ints.positive;
          default = 2;
        };
        schedule = lib.mkOption {
          type = lib.types.str;
          # The 15th keeps clear of the monthly bcachefs scrubs on the 1st.
          default = "*-*-15 08:00:00 UTC";
          description = "When the tiles are rebuilt (systemd OnCalendar).";
        };
        smokeRequest = lib.mkOption {
          type = lib.types.attrs;
          description = "A /route request a new extract must answer before it goes live.";
        };
        serverConfig = lib.mkOption {
          type = lib.types.path;
          readOnly = true;
          default = serverConfig;
          description = "The server's generated valhalla.json.";
        };
      };

      config = lib.mkIf cfg.enable {
        users.groups.valhalla = { };
        users.users.valhalla = {
          isSystemUser = true;
          group = "valhalla";
          home = "/var/empty";
        };

        systemd.services.valhalla-tiles = {
          description = "Build the Valhalla tile extract and swap it in";
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          unitConfig.RequiresMountsFor = [ cfg.dataDir ];
          environment = {
            VALHALLA_DATA = cfg.dataDir;
            VALHALLA_PBF_URL = cfg.extractUrl;
            VALHALLA_CONCURRENCY = toString cfg.buildConcurrency;
            VALHALLA_SMOKE_REQUEST = builtins.toJSON cfg.smokeRequest;
          };
          serviceConfig = {
            Type = "oneshot";
            User = "valhalla";
            Group = "valhalla";
            # The data directory is on a pool that may mount after tmpfiles
            # runs, so it is made here, once the mount is up.
            ExecStartPre = "+${pkgs.coreutils}/bin/install -d -m 0750 -o valhalla -g valhalla ${cfg.dataDir}";
            ExecStart = "${tilesCommand pkgs}/bin/valhalla-tiles";
            # The server keeps the old extract mapped until it restarts.
            ExecStartPost = "+${config.systemd.package}/bin/systemctl restart valhalla.service";
            # The whole-US build takes hours; it runs behind media and storage.
            TimeoutStartSec = "16h";
            Nice = 19;
            CPUWeight = 20;
            IOSchedulingClass = "idle";
            MemoryMax = cfg.buildMemoryMax;
            UMask = "0027";
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ReadWritePaths = [ cfg.dataDir ];
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            RestrictSUIDSGID = true;
            RestrictAddressFamilies = [
              "AF_UNIX"
              "AF_INET"
              "AF_INET6"
            ];
          };
        };

        systemd.timers.valhalla-tiles = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = cfg.schedule;
            RandomizedDelaySec = "30min";
            Persistent = true;
            Unit = "valhalla-tiles.service";
          };
        };

        systemd.services.valhalla = {
          description = "Valhalla routing server";
          wantedBy = [ "multi-user.target" ];
          unitConfig = {
            RequiresMountsFor = [ cfg.dataDir ];
            ConditionPathExists = live;
          };
          serviceConfig = {
            User = "valhalla";
            Group = "valhalla";
            ExecStart = "${pkgs.valhalla}/bin/valhalla_service ${cfg.serverConfig} ${toString cfg.serverThreads}";
            Restart = "on-failure";
            RestartSec = "10s";
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
            RestrictNamespaces = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            LockPersonality = true;
            RestrictAddressFamilies = [
              "AF_UNIX"
              "AF_INET"
              "AF_INET6"
            ];
          };
        };

        mountainous.tailnetNames.valhalla = {
          description = "Valhalla routing tailnet proxy";
          backend = "http://127.0.0.1:${toString cfg.port}";
          after = [ "valhalla.service" ];
        };
      };
    };
}
