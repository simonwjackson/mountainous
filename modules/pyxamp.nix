# Pyxamp universal remote plus its Pyxis, Ossicle and Jellyfin sources.
#
# The daemon reads one non-secret sources.toml (Pyxamp docs/seam-step2.md). It
# names secret files; it never holds a secret. A source with a secret is wired
# only when the host's secrets/desktop/<host>.yaml holds its key, so an
# unprovisioned source is absent rather than an activation failure. sops keeps
# key names in plain text, which is what makes that test pure.
{ inputs, ... }:
{
  nixos.modules.desktop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.mountainous.features.pyxamp;
      src = cfg.sources;
      secretsFile = ../secrets/desktop + "/${config.networking.hostName}.yaml";
      provisioned =
        key:
        builtins.pathExists secretsFile
        && lib.hasInfix "\n${key}:" ("\n" + builtins.readFile secretsFile);
      secret = key: {
        sopsFile = secretsFile;
        inherit key;
        owner = "simon";
        mode = "0400";
      };
      sources =
        lib.optionalAttrs src.pyxis.enable {
          pyxis = {
            inherit (src.pyxis) url;
            token_file = config.sops.secrets."pyxamp/pyxis-token".path;
            device_name = config.networking.hostName;
          };
        }
        // lib.optionalAttrs src.ossicle.enable {
          # Ossicle has no authentication (tailnet only), so no token_file.
          ossicle = { inherit (src.ossicle) url; };
        }
        // lib.optionalAttrs src.jellyfin.enable {
          jellyfin = {
            inherit (src.jellyfin) url user;
            api_key_file = config.sops.secrets."pyxamp/jellyfin-api-key".path;
          };
        };
      sourcesFile = (pkgs.formats.toml { }).generate "pyxamp-sources.toml" sources;
      sourceOptions = name: url: provided: {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = provided;
          description = "Wire the ${name} source into the Pyxamp daemon.";
        };
        url = lib.mkOption {
          type = lib.types.str;
          default = url;
          description = "${name} origin reachable from this desktop.";
        };
      };
      sessionService =
        after:
        lib.mapAttrsRecursive (_: lib.mkDefault) {
          partOf = [ "graphical-session.target" ];
          after = [ "graphical-session.target" ] ++ after;
          wantedBy = [ "graphical-session.target" ];
          # Wayland and Hyprland variables come from the user manager, populated
          # before hyprland-session.target starts (modules/hyprland.nix).
          environment.DBUS_SESSION_BUS_ADDRESS = "unix:path=%t/bus";
          path = [ "/run/current-system/sw" ];
          serviceConfig = {
            Restart = "on-failure";
            RestartSec = 2;
            Slice = "session.slice";
          };
        };
    in
    {
      options.mountainous.features.pyxamp = {
        enable = lib.mkEnableOption "Pyxamp universal MPRIS remote and separate face";
        package = lib.mkOption {
          type = lib.types.package;
          default = inputs.pyxamp.packages.${pkgs.stdenv.hostPlatform.system}.default;
          description = "Combined daemon and face, with its verified Quickshell runtime.";
        };
        sources = {
          pyxis =
            sourceOptions "Pyxis" "https://pyxis.hummingbird-lake.ts.net" (provisioned "pyxamp-pyxis-token");
          ossicle = sourceOptions "Ossicle" "https://podcasts.hummingbird-lake.ts.net" true;
          jellyfin =
            sourceOptions "Jellyfin" "https://watch.hummingbird-lake.ts.net" (
              provisioned "pyxamp-jellyfin-api-key"
            )
            // {
              user = lib.mkOption {
                type = lib.types.str;
                default = "simon";
                description = "Jellyfin user name; the connector resolves its id.";
              };
            };
        };
      };

      config = lib.mkMerge [
        { mountainous.features.pyxamp.enable = lib.mkDefault true; }
        (lib.mkIf cfg.enable {
          environment.systemPackages = [ cfg.package ];
          # Bare qs -c pyxamp IPC resolves the same config as the wrapper.
          # Keep global qs for the desktop bars; pyxamp runs its own qs 0.3.2.
          hjem.users.simon.files.".config/quickshell/pyxamp".source =
            lib.mkDefault "${cfg.package}/etc/xdg/quickshell/pyxamp";
          # The same file at the daemon's default path, for a hand-started daemon.
          hjem.users.simon.files.".config/pyxamp/sources.toml".source = sourcesFile;

          sops.secrets =
            lib.optionalAttrs src.pyxis.enable {
              "pyxamp/pyxis-token" = secret "pyxamp-pyxis-token";
            }
            // lib.optionalAttrs src.jellyfin.enable {
              "pyxamp/jellyfin-api-key" = secret "pyxamp-jellyfin-api-key";
            };

          systemd.user.services.pyxamp-daemon = lib.mkMerge [
            (sessionService [ "pipewire.service" ])
            {
              description = lib.mkDefault "Pyxamp universal MPRIS remote";
              # A changed source list changes the unit, so a switch restarts it.
              environment.PYXAMP_SOURCES = "${sourcesFile}";
              serviceConfig = {
                ExecStart = lib.mkDefault "${cfg.package}/bin/pyxamp-daemon";
                UMask = lib.mkDefault "0077";
                NoNewPrivileges = lib.mkDefault true;
              };
            }
          ];
          systemd.user.services.pyxamp = lib.mkMerge [
            (sessionService [ "pyxamp-daemon.service" ])
            {
              description = lib.mkDefault "Pyxamp Quickshell face";
              wants = [ "pyxamp-daemon.service" ];
              environment.QT_QPA_PLATFORM = lib.mkDefault "wayland";
              serviceConfig.ExecStart = lib.mkDefault "${cfg.package}/bin/pyxamp";
            }
          ];
        })
      ];
    };
}
