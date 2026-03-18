# Steam Button Handler - Context-aware Steam/gaming navigation
#
# Provides a keybind (default: SUPER+G) that intelligently handles Steam access.
# When useSpecialWorkspace = true (default):
# - On gaming workspace: Toggle Steam overlay (special workspace)
# - Not on gaming workspace + game running: Switch to gaming workspace
# - Not on gaming workspace + no game: Switch to workspace, launch Steam, show overlay
# When useSpecialWorkspace = false:
# - Steam and games all go to the gaming workspace
# - Button switches to gaming workspace and launches Steam if needed
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
  gamingEnabled = osConfig.mountainous.features.gaming.enable or false;
  cfg = osConfig.mountainous.features.gaming.steamButton or {};
  steamButtonEnabled = cfg.enable or false;

  # Check if Hyprland is enabled
  hyprlandEnabled = osConfig.mountainous.features.hyprland.enable or false;

  # Get Steam package from NixOS
  steam = osConfig.programs.steam.package or pkgs.steam;

  # Tool paths
  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  jq = "${pkgs.jq}/bin/jq";

  # Configurable values
  workspace = toString (cfg.workspace or 10);
  useSpecialWorkspace = cfg.useSpecialWorkspace or true;
  specialWs = cfg.specialWorkspace or "gaming";
  keybind = cfg.keybind or "SUPER, G";

  # Steam button handler script (special workspace mode)
  steamButtonHandlerSpecial = pkgs.writeShellScript "steam-button-handler" ''
    # Context-aware Steam/gaming navigation (special workspace mode)
    # - On gaming workspace: Toggle Steam overlay
    # - Not on gaming workspace + game running: Switch to show game
    # - Not on gaming workspace + no game: Launch Steam, show overlay

    CURRENT_WS=$(${hyprctl} --instance 0 activeworkspace -j | ${jq} -r '.id')
    GAME_ON_WS=$(${hyprctl} --instance 0 clients -j | ${jq} -r '[.[] | select(.workspace.id == ${workspace} and (.class | test("^steam_app_|gamescope")))] | length')
    STEAM_RUNNING=$(${hyprctl} --instance 0 clients -j | ${jq} -r '[.[] | select(.class | test("^(steam|Steam)$"))] | length')

    if [[ "$CURRENT_WS" == "${workspace}" ]]; then
        # On gaming workspace - launch Steam if needed, then toggle overlay
        if [[ "$STEAM_RUNNING" -eq 0 ]]; then
            ${steam}/bin/steam &
            sleep 0.5
        fi
        ${hyprctl} --instance 0 dispatch togglespecialworkspace ${specialWs}
    elif [[ "$GAME_ON_WS" -gt 0 ]]; then
        # Not on gaming workspace, but game is running - switch to show it
        ${hyprctl} --instance 0 dispatch workspace ${workspace}
    else
        # Not on gaming workspace, no game - go to workspace and show Steam
        ${hyprctl} --instance 0 dispatch workspace ${workspace}
        if [[ "$STEAM_RUNNING" -eq 0 ]]; then
            ${steam}/bin/steam &
            sleep 0.5
        fi
        ${hyprctl} --instance 0 dispatch togglespecialworkspace ${specialWs}
    fi
  '';

  # Steam button handler script (regular workspace mode)
  # Launches game-session instead of local Steam
  steamButtonHandlerSimple = pkgs.writeShellScript "steam-button-handler" ''
    # Simple gaming navigation (regular workspace mode)
    # Switch to gaming workspace and launch game-session

    ${hyprctl} --instance 0 dispatch workspace ${workspace}
    game-session &
  '';

  steamButtonHandler =
    if useSpecialWorkspace
    then steamButtonHandlerSpecial
    else steamButtonHandlerSimple;
in {
  config = mkMerge [
    # Assertion: steamButton requires Hyprland
    (mkIf steamButtonEnabled {
      assertions = [
        {
          assertion = hyprlandEnabled;
          message = "mountainous.features.gaming.steamButton requires mountainous.features.hyprland.enable = true";
        }
      ];
    })

    # Actual configuration
    (mkIf (gamingEnabled && steamButtonEnabled && hyprlandEnabled) {
      mountainous.features.hyprland.extraSettings = {
        # Steam button keybind - switches to gaming workspace and launches game-session
        bind = [
          "${keybind}, exec, ${steamButtonHandler}"
        ];
      };
    })
  ];
}
