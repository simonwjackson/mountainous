{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types mkIf;
  cfg = config.mountainous.darkmode;
in {
  options.mountainous.darkmode = {
    enable = mkEnableOption "Whether to enable dark mode support";

    defaultMode = mkOption {
      type = types.enum ["dark" "light"];
      default = "dark";
      description = "Default color scheme preference";
    };

    themes = {
      kitty = {
        dark = mkOption {
          type = types.str;
          default = "Catppuccin-Frappe.conf";
          description = "Kitty theme for dark mode";
        };
        light = mkOption {
          type = types.str;
          default = "Tango_Light.conf";
          description = "Kitty theme for light mode";
        };
      };

      gtk = {
        dark = mkOption {
          type = types.str;
          default = "catppuccin-frappe-blue-standard";
          description = "GTK theme for dark mode";
        };
        light = mkOption {
          type = types.str;
          default = "catppuccin-latte-blue-standard";
          description = "GTK theme for light mode";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Configure dconf for GTK applications and Firefox
    dconf.settings = {
      "org/gnome/desktop/interface" = {
        color-scheme =
          if cfg.defaultMode == "dark"
          then "prefer-dark"
          else "default";
        gtk-theme =
          if cfg.defaultMode == "dark"
          then cfg.themes.gtk.dark
          else cfg.themes.gtk.light;
      };
    };

    # Configure GTK themes properly for Firefox and other GTK applications
    # NOTE: GTK settings.ini files are now managed dynamically by darkmode-toggle script
    # to ensure proper xdg-desktop-portal-gtk integration
    # We disable home-manager GTK config to allow dynamic file management
    gtk.enable = false;

    # Ensure xdg-desktop-portal-gtk is available for Firefox integration
    home.packages = with pkgs; [
      # GTK themes for both light and dark variants
      (catppuccin-gtk.override {
        variant = "frappe";
        accents = ["blue"];
        size = "standard";
      })
      (catppuccin-gtk.override {
        variant = "latte";
        accents = ["blue"];
        size = "standard";
      })
      # Required for dconf changes
      dconf
      # Required for gsettings binary
      glib
      # Desktop portal for Firefox
      xdg-desktop-portal-gtk
      # Kitty themes for theme switching
      kitty-themes
      # Dark mode toggle script with custom themes
      (pkgs.darkmode-toggle.override {
        kittyDarkTheme = cfg.themes.kitty.dark;
        kittyLightTheme = cfg.themes.kitty.light;
        gtkDarkTheme = cfg.themes.gtk.dark;
        gtkLightTheme = cfg.themes.gtk.light;
      })
      # Required for gsettings schemas
      gsettings-desktop-schemas
    ];

    # Configure kitty with theme switching capability
    programs.kitty = {
      enable = true;

      # Enable remote control for dynamic theme switching
      settings = {
        allow_remote_control = "yes";
        listen_on = "unix:@mykitty";
      };

      # Use theme configuration
      extraConfig = ''
        # Include default theme
        include ${
          if cfg.defaultMode == "dark"
          then "${pkgs.kitty-themes}/share/kitty-themes/themes/${cfg.themes.kitty.dark}"
          else "${pkgs.kitty-themes}/share/kitty-themes/themes/${cfg.themes.kitty.light}"
        }

        # Include dynamic theme override if it exists
        include ${config.home.homeDirectory}/.config/kitty/current-theme.conf
      '';
    };

    # Create theme-specific kitty configurations for easier switching
    xdg.configFile."kitty/themes/dark.conf".source = "${pkgs.kitty-themes}/share/kitty-themes/themes/${cfg.themes.kitty.dark}";
    xdg.configFile."kitty/themes/light.conf".source = "${pkgs.kitty-themes}/share/kitty-themes/themes/${cfg.themes.kitty.light}";

    # Set session variables for applications that might need them
    # NOTE: GTK_THEME is not set as a session variable because it would override
    # the dynamic settings.ini files managed by darkmode-toggle script
    home.sessionVariables = {
      # Other theme-related variables can go here if needed
    };

    # Initialize GTK settings.ini files with default theme
    # These will be dynamically updated by darkmode-toggle script
    home.activation.initGtkSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
      run mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
      
      # Only create initial files if they don't exist (to avoid overwriting dynamic changes)
      if [[ ! -f "$HOME/.config/gtk-3.0/settings.ini" ]]; then
        run cat > "$HOME/.config/gtk-3.0/settings.ini" << 'EOF'
[Settings]
gtk-application-prefer-dark-theme=${if cfg.defaultMode == "dark" then "1" else "0"}
gtk-theme-name=${if cfg.defaultMode == "dark" then cfg.themes.gtk.dark else cfg.themes.gtk.light}
EOF
      fi
      
      if [[ ! -f "$HOME/.config/gtk-4.0/settings.ini" ]]; then
        run cat > "$HOME/.config/gtk-4.0/settings.ini" << 'EOF'
[Settings]
gtk-application-prefer-dark-theme=${if cfg.defaultMode == "dark" then "1" else "0"}
gtk-theme-name=${if cfg.defaultMode == "dark" then cfg.themes.gtk.dark else cfg.themes.gtk.light}
EOF
      fi
    '';
  };
}
