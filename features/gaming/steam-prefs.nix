# Steam Preferences Manager - Declarative Steam Friends/Chat settings
#
# Manages Steam Friends/Chat preferences via VDF file patching:
# - Applies settings on home-manager activation
# - Optionally watches for Steam exit and re-applies settings
# - Handles auto-sign-in, notifications, and sounds declaratively
{
  config,
  lib,
  pkgs,
  osConfig ? {},
  ...
}: let
  inherit (lib) mkIf mkMerge;
  inherit (builtins) toJSON;

  # Get config from NixOS (source of truth)
  gamingEnabled = osConfig.mountainous.features.gaming.enable or false;
  cfg = osConfig.mountainous.features.gaming.steamPrefs or {};
  steamPrefsEnabled = cfg.enable or false;

  # Get Steam package from NixOS
  steam = osConfig.programs.steam.package or pkgs.steam;

  # Tool paths
  pgrep = "${pkgs.procps}/bin/pgrep";
  sleep = "${pkgs.coreutils}/bin/sleep";

  # Build settings JSON from config options
  # The Python script expects flat keys
  settingsJson = toJSON ({
      autoSignIn =
        if (cfg.friends.autoSignIn or "offline") == "online"
        then "1"
        else "0";
      showIngame = cfg.friends.notifications.showIngame or false;
      showOnline = cfg.friends.notifications.showOnline or false;
      showMessage = cfg.friends.notifications.showMessage or false;
      playIngame = cfg.friends.sounds.playIngame or false;
      playOnline = cfg.friends.sounds.playOnline or false;
      playMessage = cfg.friends.sounds.playMessage or false;
      enableStreaming =
        if (cfg.remotePlay.enable or false)
        then "1"
        else "0";
      guideButtonFocusesSteam =
        if (cfg.controller.guideButtonFocusesSteam or false)
        then "1"
        else "0";
    }
    // (
      if (cfg.compatibility.defaultTool or null) != null
      then {defaultCompatTool = cfg.compatibility.defaultTool;}
      else {}
    )
    // (
      if (cfg.shaderCache.enablePreCaching or null) != null
      then {disableShaderCache = !cfg.shaderCache.enablePreCaching;}
      else {}
    )
    // (
      if (cfg.shaderCache.enableBackgroundProcessing or null) != null
      then {enableShaderBackgroundProcessing = cfg.shaderCache.enableBackgroundProcessing;}
      else {}
    ));

  # Shared apply script - used by both activation and watcher
  applySteamPrefs = pkgs.writeShellScript "apply-steam-prefs" ''
    STEAM_ID="${cfg.steamId or ""}"
    SETTINGS='${settingsJson}'

    # Exit gracefully if no Steam ID configured
    if [[ -z "$STEAM_ID" ]]; then
      echo "steam-prefs: No Steam ID configured, skipping"
      exit 0
    fi

    # Check if Steam config directory exists
    STEAM_CONFIG_DIR="$HOME/.steam/steam/userdata/$STEAM_ID/config"
    if [[ ! -d "$STEAM_CONFIG_DIR" ]]; then
      echo "steam-prefs: Steam config directory not found at $STEAM_CONFIG_DIR"
      echo "steam-prefs: Run Steam at least once to initialize user data"
      exit 0
    fi

    # Apply settings using steam-prefs package
    echo "steam-prefs: Applying Steam preferences for user $STEAM_ID"
    ${pkgs.steam-prefs}/bin/steam-prefs "$STEAM_ID" "$SETTINGS"
  '';

  # Watcher script - monitors Steam process and re-applies on exit
  steamPrefsWatcher = pkgs.writeShellScript "steam-prefs-watcher" ''
    # Wait for Steam process to start (5 minute timeout)
    echo "steam-prefs-watcher: Waiting for Steam to start..."
    TIMEOUT=300  # 5 minutes
    ELAPSED=0

    while [[ $ELAPSED -lt $TIMEOUT ]]; do
      if ${pgrep} -x steam > /dev/null 2>&1; then
        echo "steam-prefs-watcher: Steam detected, monitoring for exit..."
        break
      fi
      ${sleep} 1
      ELAPSED=$((ELAPSED + 1))
    done

    if [[ $ELAPSED -ge $TIMEOUT ]]; then
      echo "steam-prefs-watcher: Timeout waiting for Steam, exiting"
      exit 0
    fi

    # Monitor Steam process
    while ${pgrep} -x steam > /dev/null 2>&1; do
      ${sleep} 5
    done

    # Steam exited, re-apply preferences
    echo "steam-prefs-watcher: Steam exited, re-applying preferences..."
    ${applySteamPrefs}
  '';
in {
  config = mkMerge [
    # Actual configuration
    (mkIf (gamingEnabled && steamPrefsEnabled) {
      # Add steam-prefs package to user environment
      home.packages = [pkgs.steam-prefs];

      # Apply settings on home-manager activation
      home.activation.applySteamPrefs = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run ${applySteamPrefs}
      '';
    })

    # Systemd watcher service (if enabled)
    (mkIf (gamingEnabled && steamPrefsEnabled && (cfg.reapplyOnSteamExit or true)) {
      systemd.user.services.steam-prefs-watcher = {
        Unit = {
          Description = "Steam Preferences Watcher - Re-apply settings on Steam exit";
          After = ["graphical-session.target"];
          PartOf = ["graphical-session.target"];
        };

        Service = {
          Type = "simple";
          ExecStart = "${steamPrefsWatcher}";
          Restart = "always";
          RestartSec = "30";
          StartLimitBurst = 5;
          StartLimitIntervalSec = 300;
        };

        Install = {
          WantedBy = ["graphical-session.target"];
        };
      };
    })
  ];
}
