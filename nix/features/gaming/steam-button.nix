# Steam Button Handler - Context-aware Steam/gaming navigation
#
# Provides a keybind (default: SUPER+G) that intelligently handles Steam access:
# - On gaming workspace: Toggle Steam overlay (special workspace)
# - Not on gaming workspace + game running: Switch to gaming workspace
# - Not on gaming workspace + no game: Switch to workspace, launch Steam, show overlay
{
  config,
  lib,
  pkgs,
  osConfig ? {},
  ...
}: let
  inherit (lib) mkIf mkMerge;
  inherit (builtins) toString;

  # Get config from NixOS (source of truth)
  gamingEnabled = osConfig.mountainous.gaming.enable or false;
  cfg = osConfig.mountainous.gaming.steamButton or {};
  steamButtonEnabled = cfg.enable or false;

  # Check if Hyprland is enabled
  hyprlandEnabled = osConfig.mountainous.hyprland.enable or false;

  # Get Steam package from NixOS
  steam = osConfig.programs.steam.package or pkgs.steam;

  # Tool paths
  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  jq = "${pkgs.jq}/bin/jq";

  # Configurable values
  workspace = toString (cfg.workspace or 10);
  specialWs = cfg.specialWorkspace or "gaming";
  keybind = cfg.keybind or "SUPER, G";

  # Steam button handler script
  steamButtonHandler = pkgs.writeShellScript "steam-button-handler" ''
    # Context-aware Steam/gaming navigation
    # - On gaming workspace: Toggle Steam overlay
    # - Not on gaming workspace + game running: Switch to show game
    # - Not on gaming workspace + no game: Launch Steam, show overlay

    CURRENT_WS=$(${hyprctl} activeworkspace -j | ${jq} -r '.id')
    GAME_ON_WS=$(${hyprctl} clients -j | ${jq} -r '[.[] | select(.workspace.id == ${workspace} and (.class | test("^steam_app_|gamescope")))] | length')
    STEAM_RUNNING=$(${hyprctl} clients -j | ${jq} -r '[.[] | select(.class | test("^(steam|Steam)$"))] | length')

    if [[ "$CURRENT_WS" == "${workspace}" ]]; then
        # On gaming workspace - launch Steam if needed, then toggle overlay
        if [[ "$STEAM_RUNNING" -eq 0 ]]; then
            ${steam}/bin/steam &
            sleep 0.5
        fi
        ${hyprctl} dispatch togglespecialworkspace ${specialWs}
    elif [[ "$GAME_ON_WS" -gt 0 ]]; then
        # Not on gaming workspace, but game is running - switch to show it
        ${hyprctl} dispatch workspace ${workspace}
    else
        # Not on gaming workspace, no game - go to workspace and show Steam
        ${hyprctl} dispatch workspace ${workspace}
        if [[ "$STEAM_RUNNING" -eq 0 ]]; then
            ${steam}/bin/steam &
            sleep 0.5
        fi
        ${hyprctl} dispatch togglespecialworkspace ${specialWs}
    fi
  '';
in {
  config = mkMerge [
    # Assertion: steamButton requires Hyprland
    (mkIf steamButtonEnabled {
      assertions = [
        {
          assertion = hyprlandEnabled;
          message = "mountainous.gaming.steamButton requires mountainous.hyprland.enable = true";
        }
      ];
    })

    # Actual configuration
    (mkIf (gamingEnabled && steamButtonEnabled && hyprlandEnabled) {
      mountainous.hyprland.extraSettings = {
        # Steam button keybind
        bind = [
          "${keybind}, exec, ${steamButtonHandler}"
        ];

        # Window rules for Steam and games
        windowrule = [
          # Steam client → special workspace overlay
          "workspace special:${specialWs} silent, match:class ^(steam|Steam)$"
          "workspace special:${specialWs} silent, match:title ^Steam$"

          # Steam games → gaming workspace
          "workspace ${workspace}, match:class r:^steam_app_"
          "workspace ${workspace}, match:class gamescope"

          # Games fullscreen by default
          "fullscreen on, match:class r:^steam_app_"
          "fullscreen on, match:class gamescope"
        ];
      };
    })
  ];
}
