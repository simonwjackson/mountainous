# Traccar: where Vela records Trips (Vela ADR 0008). Two tailnet names, both
# HTTPS, both on loopback backends:
#   - https://traccar.<tailnet>         the web app and REST API (port 8082)
#   - https://traccar-osmand.<tailnet>  the OsmAnd protocol (port 5055)
#
# OsmAnd gets its own HTTPS name because Vela is an HTTPS page: a browser
# blocks its requests to a plain-HTTP port. Traccar Client apps take the same
# URL. A tsnet node serves one port, so the two ports need two names.
#
# Only the OsmAnd protocol is enabled; Traccar otherwise opens about 200
# protocol ports. Trips and positions are kept forever: Traccar 6 has no
# position purge setting (no database.historyDays key), so nothing is set.
#
# Devices register themselves on their first report (database.registerUnknown),
# so Vela's traccarDeviceId needs no setup.
#
# After the first deploy, before anything else: open https://traccar.<tailnet>
# and register the administrator account (the first account made becomes the
# administrator). Then, in Settings > Server, turn off Registration so nobody
# else on the tailnet can make an account.
{ self, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      problems = lib.concatLists (
        lib.mapAttrsToList (
          host: system:
          let
            c = system.config;
            s = c.services.traccar.settings;
            names = c.mountainous.tailnetNames or { };
            want = ok: msg: lib.optional (!ok) "${host}: ${msg}";
            flat = lib.collect builtins.isString (
              lib.mapAttrsRecursive (path: _: lib.concatStringsSep "." path) s
            );
          in
          lib.optionals c.services.traccar.enable (
            want (s.web.address == "127.0.0.1") "the web port listens beyond loopback"
            ++ want (s.osmand.address == "127.0.0.1") "the OsmAnd port listens beyond loopback"
            ++ want (s.protocols.enable == "osmand") "protocols other than OsmAnd are open"
            ++ want (
              !(lib.any (key: lib.hasInfix "history" (lib.toLower key)) flat)
            ) "a setting purges position history"
            ++ want ((s.filter.enable or "false") != "true") "a position filter drops points"
            ++ want (
              (names.traccar.backend or "") == "http://127.0.0.1:${s.web.port}"
            ) "no tailnet name for the web app"
            ++ want (
              (names.traccar-osmand.backend or "") == "http://127.0.0.1:${s.osmand.port}"
            ) "no tailnet name for the OsmAnd protocol"
          )
        ) self.nixosConfigurations
      );
    in
    {
      checks.traccar =
        if problems == [ ] then
          pkgs.runCommand "traccar" { } "touch $out"
        else
          throw "traccar:\n  ${lib.concatStringsSep "\n  " problems}";
    };

  nixos.modules.traccar =
    { config, lib, ... }:
    let
      cfg = config.mountainous.features.traccar;
      s = config.services.traccar.settings;
    in
    {
      # services.traccar.settings is one untyped value: lib.mkDefault does not
      # work on a single key inside it. The values a host may change are
      # options here instead. Loopback and OsmAnd-only stay fixed
      # (checks.traccar).
      options.mountainous.features.traccar = {
        webPort = lib.mkOption {
          type = lib.types.port;
          default = 8082;
        };
        osmandPort = lib.mkOption {
          type = lib.types.port;
          default = 5055;
        };
        registerUnknown = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Create a device on its first report (database.registerUnknown).";
        };
      };

      config = {
        services.traccar = {
          enable = true;
          settings = {
            web = {
              address = "127.0.0.1";
              port = toString cfg.webPort;
            };
            protocols.enable = "osmand";
            osmand = {
              address = "127.0.0.1";
              port = toString cfg.osmandPort;
            };
            database.registerUnknown = lib.boolToString cfg.registerUnknown;
          };
        };

        mountainous.tailnetNames.traccar = {
          description = "Traccar web and API tailnet proxy";
          backend = "http://127.0.0.1:${s.web.port}";
          after = [ "traccar.service" ];
        };
        mountainous.tailnetNames.traccar-osmand = {
          description = "Traccar OsmAnd protocol tailnet proxy";
          backend = "http://127.0.0.1:${s.osmand.port}";
          after = [ "traccar.service" ];
        };
      };
    };
}
