# Citron Nintendo Switch Emulator - Home Manager Configuration
#
# Handles:
# - Automatic installation of prod keys to ~/.local/share/citron/keys/
# - Declarative configuration of ~/.config/citron/qt-config.ini
# - Smart re-installation when flake input changes (path-based detection)
{
  config,
  lib,
  pkgs,
  osConfig ? {},
  ...
}: let
  inherit (lib) mkIf mkMerge optionalString;
  inherit (builtins) toJSON;

  # Get citron config from NixOS (source of truth)
  gamingEnabled = osConfig.mountainous.gaming.enable or false;
  citronCfg = osConfig.mountainous.gaming.citron or {};
  citronEnabled = citronCfg.enable or false;
  keysPath = citronCfg.keys or null;

  # Build settings JSON for citron-config script
  # Only include non-null values
  settingsJson = toJSON (
    lib.filterAttrs (n: v: v != null) {
      # Graphics
      backend = citronCfg.graphics.backend or null;
      resolution = citronCfg.graphics.resolution or null;
      vsync = citronCfg.graphics.vsync or null;
      fullscreenMode = citronCfg.graphics.fullscreenMode or null;
      scalingFilter = citronCfg.graphics.scalingFilter or null;
      gpuAccuracy = citronCfg.graphics.gpuAccuracy or null;
      asyncShaders = citronCfg.graphics.asyncShaders or null;
      diskShaderCache = citronCfg.graphics.diskShaderCache or null;
      # System
      dockedMode = citronCfg.system.dockedMode or null;
      language = citronCfg.system.language or null;
      region = citronCfg.system.region or null;
      # Performance
      multicore = citronCfg.performance.multicore or null;
      speedLimit = citronCfg.performance.speedLimit or null;
      # Audio
      volume = citronCfg.audio.volume or null;
      muteInBackground = citronCfg.audio.muteInBackground or null;
      # UI
      fullscreen = citronCfg.ui.fullscreen or null;
      confirmStop = citronCfg.ui.confirmStop or null;
      pauseInBackground = citronCfg.ui.pauseInBackground or null;
      theme = citronCfg.ui.theme or null;
      # Game directories (always include, even if empty - script handles it)
      gameDirectories = citronCfg.gameDirectories or [];
    }
  );

  # Check if any settings are configured (not just defaults)
  hasSettings =
    (citronCfg.graphics.backend or null)
    != null
    || (citronCfg.graphics.resolution or null) != null
    || (citronCfg.graphics.vsync or null) != null
    || (citronCfg.graphics.fullscreenMode or null) != null
    || (citronCfg.graphics.scalingFilter or null) != null
    || (citronCfg.graphics.gpuAccuracy or null) != null
    || (citronCfg.graphics.asyncShaders or null) != null
    || (citronCfg.graphics.diskShaderCache or null) != null
    || (citronCfg.system.dockedMode or null) != null
    || (citronCfg.system.language or null) != null
    || (citronCfg.system.region or null) != null
    || (citronCfg.performance.multicore or null) != null
    || (citronCfg.performance.speedLimit or null) != null
    || (citronCfg.audio.volume or null) != null
    || (citronCfg.audio.muteInBackground or null) != null
    || (citronCfg.ui.fullscreen or null) != null
    || (citronCfg.ui.confirmStop or null) != null
    || (citronCfg.ui.pauseInBackground or null) != null
    || (citronCfg.ui.theme or null) != null
    || (citronCfg.gameDirectories or []) != [];

  # Script to install keys with source path tracking
  installKeysScript = pkgs.writeShellScript "install-citron-keys" ''
    set -euo pipefail

    KEYS_SRC="${keysPath}"
    KEYS_DIR="$HOME/.local/share/citron/keys"
    SOURCE_FILE="$KEYS_DIR/.source-path"

    # Check if we need to copy (source path changed = flake input updated)
    if [[ -f "$SOURCE_FILE" ]]; then
      EXISTING_SRC=$(${pkgs.coreutils}/bin/cat "$SOURCE_FILE")
      if [[ "$KEYS_SRC" == "$EXISTING_SRC" ]]; then
        echo "citron-keys: Keys already up-to-date (source: $KEYS_SRC)"
        exit 0
      fi
      echo "citron-keys: Keys source changed, updating..."
      echo "  old: $EXISTING_SRC"
      echo "  new: $KEYS_SRC"
    else
      echo "citron-keys: Installing keys for first time"
    fi

    # Create directory and copy keys
    ${pkgs.coreutils}/bin/mkdir -p "$KEYS_DIR"
    ${pkgs.coreutils}/bin/cp -f "$KEYS_SRC"/*.keys "$KEYS_DIR/"

    # Store source path for future comparisons
    echo "$KEYS_SRC" > "$SOURCE_FILE"

    echo "citron-keys: Keys installed successfully"
    ${pkgs.coreutils}/bin/ls -la "$KEYS_DIR"
  '';

  # Script to apply configuration settings
  applyConfigScript = pkgs.writeShellScript "apply-citron-config" ''
    set -euo pipefail

    echo "citron-config: Applying declarative settings..."
    ${pkgs.citron-config}/bin/citron-config '${settingsJson}'
  '';
in {
  config = mkIf (gamingEnabled && citronEnabled) (mkMerge [
    # Keys installation (if keys path provided)
    (mkIf (keysPath != null) {
      home.activation.installCitronKeys = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run ${installKeysScript}
      '';
    })

    # Config management (if any settings configured)
    (mkIf hasSettings {
      home.activation.applyCitronConfig = lib.hm.dag.entryAfter ["writeBoundary" "installCitronKeys"] ''
        run ${applyConfigScript}
      '';
    })
  ]);
}
