{
  config,
  inputs,
  lib,
  pkgs,
  osConfig ? {},
  ...
}: let
  inherit (lib) mkOption types;

  cfg = config.mountainous.hyprland;
  hyprlandEnabled = osConfig.mountainous.hyprland.enable or false;

  # Import configuration from sub-modules
  keybindsConfig = import ./keybinds.nix {inherit config lib pkgs inputs;};
  settingsConfig = import ./settings.nix {inherit lib pkgs;};
  windowrulesConfig = import ./windowrules.nix {inherit lib pkgs;};
  hyprlockConfig = import ./hyprlock.nix {inherit lib pkgs;};

  # List of attributes that should be merged (concatenated) instead of replaced
  # NOTE: "monitor" intentionally excluded - user settings should replace defaults
  listAttrs = [
    "exec-once"
    "env"
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

  # Function to merge lists for a specific attribute from default and extra settings
  mergeListAttr = attr: let
    defaultList = defaultSettings.${attr} or [];
    extraList = cfg.extraSettings.${attr} or [];
  in
    if (defaultList != [] || extraList != [])
    then {${attr} = defaultList ++ extraList;}
    else {};

  # Merge all list attributes
  mergedLists = lib.foldl' (acc: attr: acc // (mergeListAttr attr)) {} listAttrs;

  # Final merged settings:
  # 1. Start with defaultSettings
  # 2. Apply extraSettings (non-list attrs override, list attrs get replaced temporarily)
  # 3. Apply mergedLists to restore proper list concatenation
  mergedSettings =
    lib.recursiveUpdate
    (lib.recursiveUpdate defaultSettings cfg.extraSettings)
    mergedLists;
in {
  imports = [
    inputs.hyprland.homeManagerModules.default
  ];

  options.mountainous.hyprland = {
    extraSettings = mkOption {
      type = types.submodule {
        freeformType = types.attrsOf types.anything;
        options = {
          # Define list attributes explicitly so they merge properly
          bind = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Extra keybindings";
          };
          bindel = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Extra keybindings (repeat on hold, release)";
          };
          bindl = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Extra keybindings (locked)";
          };
          bindm = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Extra mouse bindings";
          };
          exec-once = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Commands to execute once at startup";
          };
          windowrule = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Extra window rules";
          };
          env = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Environment variables";
          };
        };
      };
      default = {};
      description = ''
        Additional settings to merge with the default configuration.
        List attributes (bind, exec-once, windowrule, etc.) are concatenated.
        Other attributes are merged recursively.
      '';
    };

    plugins = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "List of Hyprland plugins to load";
    };

    enableHypridle = mkOption {
      type = types.bool;
      default = true;
      description = "Enable hypridle for idle management (disable for servers)";
    };
  };

  config = lib.mkIf hyprlandEnabled {
    # Add tools to PATH
    home.packages = [
      pkgs.wtype
      pkgs.sox
      # Screenshot tools
      pkgs.grim
      pkgs.slurp
      pkgs.satty
      pkgs.wl-clipboard
      pkgs.libnotify
    ];

    programs.hyprlock = hyprlockConfig.hyprlock;
    services.hypridle = lib.mkIf cfg.enableHypridle hyprlockConfig.hypridle;

    wayland.windowManager.hyprland = {
      enable = true;
      package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
      portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
      plugins = cfg.plugins;
      settings = mergedSettings;
    };
  };
}
