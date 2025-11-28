{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;

  cfg = config.mountainous.hyprland;

  # Import configuration from sub-modules
  keybindsConfig = import ./keybinds.nix {inherit lib pkgs inputs;};
  settingsConfig = import ./settings.nix {inherit lib pkgs;};
  windowrulesConfig = import ./windowrules.nix {inherit lib pkgs;};
  hyprlockConfig = import ./hyprlock.nix {inherit lib pkgs;};

  # List of attributes that should be merged instead of replaced
  listAttrs = [
    "exec-once"
    "env"
    "monitor"
    "bind"
    "bindel"
    "bindl"
    "bindm"
    "windowrule"
    "animation"
    "bezier"
  ];

  # Default settings combining all imported configs
  defaultSettings =
    settingsConfig
    // keybindsConfig
    // windowrulesConfig;

  # Function to merge lists for a specific attribute
  mergeListAttr = attr:
    if (defaultSettings ? ${attr} && cfg.extraSettings ? ${attr})
    then {${attr} = (defaultSettings.${attr} or []) ++ (cfg.extraSettings.${attr} or []);}
    else {};

  # Merge all list attributes
  mergedLists = lib.foldl' (acc: attr: acc // (mergeListAttr attr)) {} listAttrs;

  # Final merged settings
  mergedSettings =
    lib.recursiveUpdate
    (lib.recursiveUpdate defaultSettings cfg.extraSettings)
    mergedLists;
in {
  imports = [
    inputs.hyprland.homeManagerModules.default
  ];

  options.mountainous.hyprland = {
    enable = mkEnableOption "Whether to enable the hyprland desktop";

    extraSettings = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional settings to merge with the default configuration";
    };

    plugins = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "List of Hyprland plugins to load";
    };
  };

  config = lib.mkIf cfg.enable {
    # Add tools to PATH
    home.packages = [
      pkgs.wtype
      pkgs.sox
    ];

    programs.hyprlock = hyprlockConfig.hyprlock;
    services.hypridle = hyprlockConfig.hypridle;

    wayland.windowManager.hyprland = {
      enable = true;
      package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
      portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
      plugins = cfg.plugins;
      settings = mergedSettings;
    };
  };
}
