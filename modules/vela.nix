# Vela, the car dashboard PWA (github.com/simonwjackson/vela), served on the
# tailnet as https://vela.<tailnet>. Vela's own module (inputs.vela) owns the
# package and services.vela.settings, which it writes to /etc/vela/config.json.
# Its personal values are set on the host (Vela ADR 0005, 0006).
#
# Vela's module does not serve anything yet. Until it does, this layer adds the
# static server and the tailnet name:
#   - nginx on loopback (services.vela.port). nixpkgs' nginx derives ETags from
#     the store path, so a new build is never answered with a stale 304.
#     /config.json, the HTML and the service worker are never cached; the
#     content-hashed files in /assets/ are cached for a year.
#   - the tailnet name `vela` (modules/tailnet-names.nix) in front of it.
#
# The browser calls each service directly from Vela's origin (Vela ADR 0001),
# so that origin must be in each service's allowlist. The assistant's list is
# mountainous.features.pi-assistant.extraWebOrigins; Pyxis, Ossicle and
# voice-gateway run on Zao outside this flake.
{ inputs, self, ... }:
let
  # Names of the services Vela calls that this flake places, with the tailnet
  # name each origin must use.
  fleetOrigins = {
    valhalla = "valhalla";
    traccar = "traccar-osmand";
  };
in
{
  perSystem =
    { pkgs, lib, ... }:
    let
      # Every tailnet name any fleet host serves.
      fleetNames = lib.concatLists (
        lib.mapAttrsToList (
          _: system: lib.attrNames (system.config.mountainous.tailnetNames or { })
        ) self.nixosConfigurations
      );
      problems = lib.concatLists (
        lib.mapAttrsToList (
          host: system:
          let
            c = system.config;
            cfg = c.mountainous.features.vela or null;
            settings = c.services.vela.settings;
            origins = settings.origins or { };
            want = ok: msg: lib.optional (!ok) "${host}: ${msg}";
            exact = origin: builtins.match "https://[a-z0-9.-]+" origin != null;
            nameOf = origin: lib.head (lib.splitString "." (lib.removePrefix "https://" origin));
            assistant = c.mountainous.features.pi-assistant or null;
            vhost = c.services.nginx.virtualHosts.vela;
          in
          lib.optionals (cfg != null && c.services.vela.enable) (
            lib.concatMap (
              key:
              want (origins ? ${key}) "origins.${key} is missing"
              ++ want (exact (origins.${key} or "")) "origins.${key} is not an exact https origin"
            ) cfg.requiredOrigins
            ++ lib.concatLists (
              lib.mapAttrsToList (
                key: name:
                want (nameOf (origins.${key} or "") == name) "origins.${key} does not use the tailnet name ${name}"
                ++ want (lib.elem name fleetNames) "no fleet host serves the tailnet name ${name}"
              ) fleetOrigins
            )
            ++ want (lib.isString (settings.photonUrl or null)) "photonUrl is missing"
            ++ want (lib.isString (settings.traccarDeviceId or null)) "traccarDeviceId is missing"
            ++ want (lib.isInt (settings.turnSoundLeadMs or null)) "turnSoundLeadMs is missing"
            ++ want (exact cfg.origin) "Vela's own origin is not an exact https origin"
            ++ want (
              (c.mountainous.tailnetNames.${cfg.tailnetName}.backend or "")
              == "http://127.0.0.1:${toString c.services.vela.port}"
            ) "no tailnet name in front of the static server"
            ++ want (lib.all (
              l: l.addr == "127.0.0.1"
            ) vhost.listen) "the static server listens beyond loopback"
            ++ want (
              assistant == null || assistant.people == { } || lib.elem cfg.origin assistant.extraWebOrigins
            ) "the assistant on this host does not allow Vela's origin"
          )
        ) self.nixosConfigurations
      );
    in
    {
      checks.vela =
        if problems == [ ] then
          pkgs.runCommand "vela" { } "touch $out"
        else
          throw "vela:\n  ${lib.concatStringsSep "\n  " problems}";
    };

  nixos.modules.vela =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.mountainous.features.vela;
      vela = config.services.vela;
      noStore = ''
        add_header Cache-Control "no-store" always;
      '';
    in
    {
      imports = [ inputs.vela.nixosModules.default ];

      options.mountainous.features.vela = {
        tailnet = lib.mkOption {
          type = lib.types.str;
          example = "example.ts.net";
        };
        tailnetName = lib.mkOption {
          type = lib.types.str;
          default = "vela";
        };
        origin = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          default = "https://${cfg.tailnetName}.${cfg.tailnet}";
          description = "Vela's exact browser origin. Services Vela calls must allow it.";
        };
        requiredOrigins = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          internal = true;
          readOnly = true;
          # Vela's src/contract/config.ts: VelaConfig.origins.
          default = [
            "pyxis"
            "ossicle"
            "assistant"
            "voice"
            "valhalla"
            "traccar"
          ];
        };
      };

      config = {
        services.vela.enable = lib.mkDefault true;

        services.nginx = lib.mkIf vela.enable {
          enable = true;
          recommendedGzipSettings = true;
          virtualHosts.vela = {
            listen = [
              {
                addr = "127.0.0.1";
                port = vela.port;
              }
            ];
            root = "${vela.package}";
            locations = {
              "= /config.json" = {
                alias = config.environment.etc."vela/config.json".source;
                extraConfig = noStore + ''
                  default_type application/json;
                '';
              };
              "/assets/".extraConfig = ''
                add_header Cache-Control "public, max-age=31536000, immutable" always;
              '';
              "/".extraConfig = noStore;
            };
          };
        };

        mountainous.tailnetNames.${cfg.tailnetName} = lib.mkIf vela.enable {
          description = "Vela car dashboard tailnet proxy";
          backend = "http://127.0.0.1:${toString vela.port}";
          after = [ "nginx.service" ];
        };
      };
    };
}
