# Citron Nintendo Switch Emulator - Home Manager Configuration
#
# Handles:
# - Automatic installation of prod keys to ~/.local/share/citron/keys/
# - Declarative configuration of ~/.config/citron/qt-config.ini
# - Symlink management for shared NAND (saves + user profile)
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
  savePath = citronCfg.savePath or null;

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
      antiAliasing = citronCfg.graphics.antiAliasing or null;
      fsrSharpness = citronCfg.graphics.fsrSharpness or null;
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
      # Controls (always include, even if empty - script handles it)
      controls = citronCfg.controls or {};
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
    || (citronCfg.graphics.antiAliasing or null) != null
    || (citronCfg.graphics.fsrSharpness or null) != null
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
    || (citronCfg.gameDirectories or []) != []
    || (citronCfg.controls or {}) != {};

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

  # Script to symlink NAND directory for shared saves
  # Hybrid approach: automatic backup + loud warning with migration instructions
  symlinkNandScript = pkgs.writeShellScript "symlink-citron-nand" ''
    set -euo pipefail

    NAND_TARGET="${savePath}"
    NAND_LINK="$HOME/.local/share/citron/nand"
    CITRON_DIR="$HOME/.local/share/citron"
    PROFILES_SUBPATH="system/save/8000000000000010/su/avators/profiles.dat"

    # Helper to extract UUID from profiles.dat (little-endian at offset 0x10)
    extract_uuid() {
      local profiles_file="$1"
      if [[ -f "$profiles_file" ]]; then
        ${pkgs.coreutils}/bin/od -A n -t x1 -j 16 -N 16 "$profiles_file" 2>/dev/null | \
          ${pkgs.gawk}/bin/awk '{for(i=NF;i>=1;i--) printf "%s", toupper($i); print ""}'
      fi
    }

    # Ensure citron data directory exists
    ${pkgs.coreutils}/bin/mkdir -p "$CITRON_DIR"

    # Check current state
    if [[ -L "$NAND_LINK" ]]; then
      # Already a symlink
      CURRENT_TARGET=$(${pkgs.coreutils}/bin/readlink "$NAND_LINK")
      if [[ "$CURRENT_TARGET" == "$NAND_TARGET" ]]; then
        echo "citron-nand: Symlink already correct ($NAND_LINK -> $NAND_TARGET)"
        exit 0
      fi
      echo "citron-nand: Updating symlink..."
      echo "  old target: $CURRENT_TARGET"
      echo "  new target: $NAND_TARGET"
      ${pkgs.coreutils}/bin/rm "$NAND_LINK"

    elif [[ -d "$NAND_LINK" ]]; then
      # Existing local installation - backup and warn
      BACKUP_PATH="$NAND_LINK.backup.$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)"
      LOCAL_UUID=$(extract_uuid "$NAND_LINK/$PROFILES_SUBPATH")
      SHARED_UUID=$(extract_uuid "$NAND_TARGET/$PROFILES_SUBPATH")

      echo ""
      echo "========================================================================"
      echo "  CITRON: Existing local installation detected"
      echo "========================================================================"
      echo ""
      echo "  Backing up local data to:"
      echo "    $BACKUP_PATH"
      echo ""

      ${pkgs.coreutils}/bin/mv "$NAND_LINK" "$BACKUP_PATH"

      # Warn about potential save migration
      echo "  LOCAL UUID:  ''${LOCAL_UUID:-<not found>}"
      echo "  SHARED UUID: ''${SHARED_UUID:-<not found>}"
      echo ""

      if [[ -n "$LOCAL_UUID" && -n "$SHARED_UUID" && "$LOCAL_UUID" != "$SHARED_UUID" ]]; then
        echo "  !! WARNING: UUID MISMATCH !!"
        echo ""
        echo "  Your local saves use a different user profile than the shared storage."
        echo "  Saves will NOT appear in Citron until migrated."
        echo ""
        echo "  To migrate your local saves to shared storage:"
        echo ""
        echo "    1. Copy your saves to the shared UUID folder:"
        echo "       cp -r $BACKUP_PATH/user/save/0000000000000000/$LOCAL_UUID/* \\"
        echo "         $NAND_TARGET/user/save/0000000000000000/$SHARED_UUID/"
        echo ""
        echo "    2. Or copy all saves if shared UUID folder doesn't have them:"
        echo "       mkdir -p $NAND_TARGET/user/save/0000000000000000/$SHARED_UUID"
        echo "       cp -rn $BACKUP_PATH/user/save/0000000000000000/$LOCAL_UUID/* \\"
        echo "         $NAND_TARGET/user/save/0000000000000000/$SHARED_UUID/"
        echo ""
      elif [[ -n "$LOCAL_UUID" && -z "$SHARED_UUID" ]]; then
        echo "  NOTE: No existing shared profile found."
        echo "  Seeding shared storage with your local profile..."
        echo ""
        # Copy local system data to shared location to preserve UUID
        if [[ -d "$BACKUP_PATH/system" ]]; then
          ${pkgs.coreutils}/bin/cp -rn "$BACKUP_PATH/system/"* "$NAND_TARGET/system/" 2>/dev/null || true
        fi
        if [[ -d "$BACKUP_PATH/user" ]]; then
          ${pkgs.coreutils}/bin/cp -rn "$BACKUP_PATH/user/"* "$NAND_TARGET/user/" 2>/dev/null || true
        fi
        echo "  Local profile and saves copied to shared storage."
        echo ""
      fi

      echo "========================================================================"
      echo ""

    elif [[ -e "$NAND_LINK" ]]; then
      echo "citron-nand: ERROR: $NAND_LINK exists but is not a directory or symlink"
      exit 1
    fi

    # Verify target exists
    if [[ ! -d "$NAND_TARGET" ]]; then
      echo "citron-nand: ERROR: Target directory does not exist: $NAND_TARGET"
      echo "  Please ensure the save path exists before activating."
      exit 1
    fi

    # Create symlink
    ${pkgs.coreutils}/bin/ln -s "$NAND_TARGET" "$NAND_LINK"
    echo "citron-nand: Symlink created ($NAND_LINK -> $NAND_TARGET)"
  '';
in {
  config = mkIf (gamingEnabled && citronEnabled) (mkMerge [
    # NAND symlink for shared saves (if savePath provided)
    (mkIf (savePath != null) {
      home.activation.symlinkCitronNand = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run ${symlinkNandScript}
      '';
    })

    # Keys installation (if keys path provided)
    (mkIf (keysPath != null) {
      home.activation.installCitronKeys = lib.hm.dag.entryAfter ["writeBoundary" "symlinkCitronNand"] ''
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
