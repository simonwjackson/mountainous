{
  config,
  lib,
  pkgs,
  osConfig ? {},
  ...
}: let
  inherit (lib) mkDefault mkEnableOption mkIf mkOption optionalAttrs types;

  cfg = config.mountainous.theme;
  geoclueEnabled = osConfig.services.geoclue2.enable or false;

  darkGtkTheme = "Tokyonight-Dark";
  lightGtkTheme = "Tokyonight-Light";
  darkKittyTheme = "${pkgs.kitty-themes}/share/kitty-themes/themes/tokyo_night_night.conf";
  lightKittyTheme = "${pkgs.kitty-themes}/share/kitty-themes/themes/tokyo_night_day.conf";

  gtkSettings = mode: let
    preferDark = if mode == "dark" then "1" else "0";
    gtkTheme = if mode == "dark" then darkGtkTheme else lightGtkTheme;
  in ''
    [Settings]
    gtk-application-prefer-dark-theme=${preferDark}
    gtk-theme-name=${gtkTheme}
  '';

  gtk4Css = mode: let
    gtkTheme = if mode == "dark" then darkGtkTheme else lightGtkTheme;
  in ''
    @import url("file://${pkgs.tokyonight-gtk-theme}/share/themes/${gtkTheme}/gtk-4.0/gtk.css");
  '';

  tofiConfig = mode:
    if mode == "dark"
    then ''
      font = "monospace"
      font-size = 14
      prompt-text = "run: "
      width = 42%
      height = 38%
      outline-width = 0
      border-width = 2
      corner-radius = 12
      result-spacing = 8
      padding-top = 12
      padding-bottom = 12
      padding-left = 16
      padding-right = 16
      background-color = #1a1b26
      border-color = #7aa2f7
      text-color = #c0caf5
      prompt-color = #bb9af7
      input-color = #c0caf5
      placeholder-color = #565f89
      selection-color = #7aa2f7
      selection-match-color = #1a1b26
    ''
    else ''
      font = "monospace"
      font-size = 14
      prompt-text = "run: "
      width = 42%
      height = 38%
      outline-width = 0
      border-width = 2
      corner-radius = 12
      result-spacing = 8
      padding-top = 12
      padding-bottom = 12
      padding-left = 16
      padding-right = 16
      background-color = #e1e2e7
      border-color = #2e7de9
      text-color = #3760bf
      prompt-color = #9854f1
      input-color = #3760bf
      placeholder-color = #848cb5
      selection-color = #2e7de9
      selection-match-color = #e1e2e7
    '';

  darkGtkSettingsFile = pkgs.writeText "mountainous-gtk-dark.ini" (gtkSettings "dark");
  lightGtkSettingsFile = pkgs.writeText "mountainous-gtk-light.ini" (gtkSettings "light");
  darkGtk4CssFile = pkgs.writeText "mountainous-gtk4-dark.css" (gtk4Css "dark");
  lightGtk4CssFile = pkgs.writeText "mountainous-gtk4-light.css" (gtk4Css "light");
  darkTofiConfigFile = pkgs.writeText "mountainous-tofi-dark.conf" (tofiConfig "dark");
  lightTofiConfigFile = pkgs.writeText "mountainous-tofi-light.conf" (tofiConfig "light");
  darkKittyCurrentThemeFile = pkgs.writeText "mountainous-kitty-dark.conf" ''
    include ${darkKittyTheme}
  '';
  lightKittyCurrentThemeFile = pkgs.writeText "mountainous-kitty-light.conf" ''
    include ${lightKittyTheme}
  '';

  applyThemeScript = pkgs.writeShellScript "mountainous-apply-theme" ''
    set -eu

    mode="''${1:?usage: mountainous-apply-theme <dark|light>}"

    case "$mode" in
      dark)
        colorScheme="prefer-dark"
        gtkTheme="${darkGtkTheme}"
        kittyTheme="${darkKittyTheme}"
        gtkSettingsFile="${darkGtkSettingsFile}"
        gtk4CssFile="${darkGtk4CssFile}"
        tofiConfigFile="${darkTofiConfigFile}"
        ;;
      light)
        colorScheme="prefer-light"
        gtkTheme="${lightGtkTheme}"
        kittyTheme="${lightKittyTheme}"
        gtkSettingsFile="${lightGtkSettingsFile}"
        gtk4CssFile="${lightGtk4CssFile}"
        tofiConfigFile="${lightTofiConfigFile}"
        ;;
      *)
        echo "invalid mode: $mode" >&2
        exit 1
        ;;
    esac

    mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" "$HOME/.config/kitty" "$HOME/.config/tofi"

    rm -f "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini" "$HOME/.config/gtk-4.0/gtk.css" "$HOME/.config/tofi/config" "$HOME/.config/kitty/current-theme.conf"

    ${pkgs.coreutils}/bin/install -m 0644 "$gtkSettingsFile" "$HOME/.config/gtk-3.0/settings.ini"
    ${pkgs.coreutils}/bin/install -m 0644 "$gtkSettingsFile" "$HOME/.config/gtk-4.0/settings.ini"
    ${pkgs.coreutils}/bin/install -m 0644 "$gtk4CssFile" "$HOME/.config/gtk-4.0/gtk.css"
    ${pkgs.coreutils}/bin/install -m 0644 "$tofiConfigFile" "$HOME/.config/tofi/config"
    ${pkgs.coreutils}/bin/install -m 0644 /dev/null "$HOME/.config/kitty/current-theme.conf"
    ${pkgs.coreutils}/bin/printf 'include %s\n' "$kittyTheme" > "$HOME/.config/kitty/current-theme.conf"

    ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'"$colorScheme"'"
    ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/gtk-theme "'"$gtkTheme"'"

    sockets=$(${pkgs.iproute2}/bin/ss -lx 2>/dev/null | ${pkgs.gnugrep}/bin/grep -oE '@mountainous-kitty(-[0-9]+)?' || true)
    if [ -n "$sockets" ]; then
      for socket in $sockets; do
        ${pkgs.kitty}/bin/kitty @ --to "unix:$socket" set-colors --all --configured "$kittyTheme" >/dev/null 2>&1 || true
      done
    fi

    ${pkgs.ironbar}/bin/ironbar reload >/dev/null 2>&1 || true
  '';
in {
  options.mountainous.theme = {
    enable = mkEnableOption "Tokyo Night driven appearance management for workstation sessions";

    defaultMode = mkOption {
      type = types.enum ["dark" "light"];
      default = "dark";
      description = "The default appearance written to user config files before darkman applies any runtime changes.";
    };
  };

  config = mkIf cfg.enable {
    dconf.settings."org/gnome/desktop/interface" = {
      color-scheme = if cfg.defaultMode == "dark" then "prefer-dark" else "prefer-light";
      gtk-theme = if cfg.defaultMode == "dark" then darkGtkTheme else lightGtkTheme;
    };

    home.packages = [
      pkgs.tokyonight-gtk-theme
    ];

    programs.kitty = {
      enable = mkDefault true;
      settings = {
        allow_remote_control = "yes";
        listen_on = "unix:@mountainous-kitty";
      };
      extraConfig = ''
        include ${config.home.homeDirectory}/.config/kitty/current-theme.conf
      '';
    };

    services.darkman = {
      enable = true;
      settings = {
        dbusserver = true;
        portal = true;
      }
      // optionalAttrs geoclueEnabled {
        usegeoclue = true;
      };
      darkModeScripts.apply-theme = ''
        exec ${applyThemeScript} dark
      '';
      lightModeScripts.apply-theme = ''
        exec ${applyThemeScript} light
      '';
    };

    home.activation.initThemeFiles = lib.hm.dag.entryAfter ["writeBoundary"] ''
      run mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" "$HOME/.config/kitty" "$HOME/.config/tofi"

      run rm -f "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini" "$HOME/.config/gtk-4.0/gtk.css" "$HOME/.config/kitty/current-theme.conf" "$HOME/.config/tofi/config"

      run install -m 0644 ${if cfg.defaultMode == "dark" then darkGtkSettingsFile else lightGtkSettingsFile} "$HOME/.config/gtk-3.0/settings.ini"
      run install -m 0644 ${if cfg.defaultMode == "dark" then darkGtkSettingsFile else lightGtkSettingsFile} "$HOME/.config/gtk-4.0/settings.ini"
      run install -m 0644 ${if cfg.defaultMode == "dark" then darkGtk4CssFile else lightGtk4CssFile} "$HOME/.config/gtk-4.0/gtk.css"
      run install -m 0644 ${if cfg.defaultMode == "dark" then darkTofiConfigFile else lightTofiConfigFile} "$HOME/.config/tofi/config"
      run install -m 0644 ${if cfg.defaultMode == "dark" then darkKittyCurrentThemeFile else lightKittyCurrentThemeFile} "$HOME/.config/kitty/current-theme.conf"
    '';
  };
}
