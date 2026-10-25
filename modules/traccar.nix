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
# so Vela's traccarDeviceId needs no setup. The first account made in the web
# app becomes the administrator: make it at once after the first deploy.
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
    { config, ... }:
    let
      s = config.services.traccar.settings;
    in
    {
      services.traccar = {
        enable = true;
        settings = {
          web = {
            address = "127.0.0.1";
            port = "8082";
          };
          protocols.enable = "osmand";
          osmand = {
            address = "127.0.0.1";
            port = "5055";
          };
          database.registerUnknown = "true";
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
}
