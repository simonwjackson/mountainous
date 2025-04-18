# webapp.nix
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.webapps;

  # Extension type for validating extension configurations
  extensionType = types.str; # Changed to string type to match NixOS chromium module

  # Default extensions that will be included in all web apps
  defaultExtensions = [
    "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
  ];

  # Web app type for validating individual web app configurations
  webAppType = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "Name of the web app (used for the executable)";
      };
      url = mkOption {
        type = types.str;
        description = "URL to load in the web app";
      };
      windowState = mkOption {
        type = types.enum ["maximized" "normal" "kiosk"];
        default = "normal";
        description = "Window state of the web app";
      };
      windowSize = mkOption {
        type = types.nullOr (types.submodule {
          options = {
            width = mkOption {
              type = types.int;
              description = "Window width in pixels";
            };
            height = mkOption {
              type = types.int;
              description = "Window height in pixels";
            };
          };
        });
        default = null;
        description = "Window size (if not maximized or kiosk)";
      };
      windowPosition = mkOption {
        type = types.nullOr (types.submodule {
          options = {
            x = mkOption {
              type = types.int;
              description = "Window X position";
            };
            y = mkOption {
              type = types.int;
              description = "Window Y position";
            };
          };
        });
        default = null;
        description = "Window position on screen";
      };
      extensions = mkOption {
        type = types.listOf extensionType;
        default = [];
        description = "Additional Chrome extensions to install (Chrome Web Store IDs)";
        example = ["cjpalhdlnbpafiamejdnhcphjbkeiagm"];
      };
      extraFlags = mkOption {
        type = types.listOf types.str;
        default = [
          "--no-first-run"
          "--noerrdialogs"
          "--disable-translate"
          "--disable-features=TranslateUI"
          "--disable-session-crashed-bubble"
          "--disable-infobars"
        ];
        description = "Additional command-line flags for Chromium";
      };
    };
  };

  # Function to create a launch script for a web app
  mkWebAppScript = name: webapp:
    pkgs.writeScriptBin webapp.name ''
      #!${pkgs.stdenv.shell}

      # Prepare extensions loading flags
      EXTENSIONS_FLAGS=""
      ${concatMapStrings (ext: ''
        if [ -d "/run/current-system/sw/share/chromium/extensions/${ext}" ]; then
          EXTENSIONS_FLAGS="$EXTENSIONS_FLAGS --load-extension=/run/current-system/sw/share/chromium/extensions/${ext}"
        fi
      '') (defaultExtensions ++ webapp.extensions)}

      # Prepare window state flags
      WINDOW_FLAGS=""
      ${
        if webapp.windowState == "maximized"
        then ''
          WINDOW_FLAGS="$WINDOW_FLAGS --start-maximized"
        ''
        else if webapp.windowState == "kiosk"
        then ''
          WINDOW_FLAGS="$WINDOW_FLAGS --kiosk"
        ''
        else ""
      }

      ${optionalString (webapp.windowSize != null) ''
        WINDOW_FLAGS="$WINDOW_FLAGS --window-size=${toString webapp.windowSize.width},${toString webapp.windowSize.height}"
      ''}

      ${optionalString (webapp.windowPosition != null) ''
        WINDOW_FLAGS="$WINDOW_FLAGS --window-position=${toString webapp.windowPosition.x},${toString webapp.windowPosition.y}"
      ''}

      # Launch Chromium with all configured flags
      exec ${pkgs.chromium}/bin/chromium \
        --app="${webapp.url}" \
        $WINDOW_FLAGS \
        $EXTENSIONS_FLAGS \
        ${concatStringsSep " " webapp.extraFlags}
    '';
in {
  options = {
    programs.webapps = mkOption {
      default = {};
      type = types.attrsOf webAppType;
      description = ''
        Web applications to create using Chromium.
        Each attribute defines a web app with its configuration.
      '';
      example = literalExpression ''
        {
          "youtube-app" = {
            name = "youtube";
            url = "https://youtube.com";
            windowState = "maximized";
            extensions = [ "cjpalhdlnbpafiamejdnhcphjbkeiagm" ];  # uBlock Origin
          };
        }
      '';
    };
  };

  config = mkIf (cfg != {}) {
    # Enable Chromium for extension installation
    programs.chromium = {
      enable = true;
      extensions = unique (defaultExtensions ++ flatten (mapAttrsToList (_: webapp: webapp.extensions) cfg));
    };

    # Create the launch scripts for all configured web apps
    environment.systemPackages = mapAttrsToList (name: webapp: mkWebAppScript name webapp) cfg;
  };
}
