# RPCS3 PS3 Emulator - Home Manager Configuration
#
# Handles:
# - Symlink management for savedata directory (shared saves across machines)
# - Symlink management for game directory (shared installs/patches across machines)
# - VFS configuration for games directory (disc games in JB folder format)
#
# Firmware must be installed manually via RPCS3's File → Install Firmware menu.
# To get firmware:
#   1. Search: "PS3UPDAT.PUP site:playstation.com"
#   2. Download from Sony's official support page
#   3. In RPCS3: File → Install Firmware → select the PUP file
{
  config,
  lib,
  pkgs,
  osConfig ? {},
  ...
}: let
  inherit (lib) mkIf mkMerge;

  gamingEnabled = osConfig.mountainous.features.gaming.enable or false;
  rpcs3Cfg = osConfig.mountainous.features.gaming.rpcs3 or {};
  rpcs3Enabled = rpcs3Cfg.enable or false;
  savePath = rpcs3Cfg.savePath or null;
  installPath = rpcs3Cfg.installPath or null;
  gamePath = rpcs3Cfg.gamePath or null;

  # Normalize gamePath to ensure trailing slash
  normalizedGamePath =
    if gamePath != null
    then
      (
        if lib.hasSuffix "/" gamePath
        then gamePath
        else gamePath + "/"
      )
    else null;

  # Script to symlink savedata directory for shared saves
  symlinkSavedataScript = pkgs.writeShellScript "symlink-rpcs3-savedata" ''
    set -euo pipefail

    SAVE_TARGET="${savePath}"
    SAVE_LINK="$HOME/.config/rpcs3/dev_hdd0/home/00000001/savedata"
    RPCS3_DIR="$HOME/.config/rpcs3/dev_hdd0/home/00000001"

    # Ensure RPCS3 data directory exists
    ${pkgs.coreutils}/bin/mkdir -p "$RPCS3_DIR"

    # Check current state
    if [[ -L "$SAVE_LINK" ]]; then
      # Already a symlink
      CURRENT_TARGET=$(${pkgs.coreutils}/bin/readlink "$SAVE_LINK")
      if [[ "$CURRENT_TARGET" == "$SAVE_TARGET" ]]; then
        echo "rpcs3-savedata: Symlink already correct ($SAVE_LINK -> $SAVE_TARGET)"
        exit 0
      fi
      echo "rpcs3-savedata: Updating symlink..."
      echo "  old target: $CURRENT_TARGET"
      echo "  new target: $SAVE_TARGET"
      ${pkgs.coreutils}/bin/rm "$SAVE_LINK"

    elif [[ -d "$SAVE_LINK" ]]; then
      # Existing local directory - backup and warn
      BACKUP_PATH="$SAVE_LINK.backup.$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)"

      echo ""
      echo "========================================================================"
      echo "  RPCS3: Existing local savedata detected"
      echo "========================================================================"
      echo ""
      echo "  Backing up local saves to:"
      echo "    $BACKUP_PATH"
      echo ""
      echo "  You may want to migrate these saves to your shared location:"
      echo "    cp -r $BACKUP_PATH/* $SAVE_TARGET/"
      echo ""
      echo "========================================================================"
      echo ""

      ${pkgs.coreutils}/bin/mv "$SAVE_LINK" "$BACKUP_PATH"

    elif [[ -e "$SAVE_LINK" ]]; then
      echo "rpcs3-savedata: ERROR: $SAVE_LINK exists but is not a directory or symlink"
      exit 1
    fi

    # Verify target exists
    if [[ ! -d "$SAVE_TARGET" ]]; then
      echo "rpcs3-savedata: Creating target directory: $SAVE_TARGET"
      ${pkgs.coreutils}/bin/mkdir -p "$SAVE_TARGET"
    fi

    # Create symlink
    ${pkgs.coreutils}/bin/ln -s "$SAVE_TARGET" "$SAVE_LINK"
    echo "rpcs3-savedata: Symlink created ($SAVE_LINK -> $SAVE_TARGET)"
  '';

  # Script to symlink game directory for shared installs/patches
  symlinkInstallScript = pkgs.writeShellScript "symlink-rpcs3-install" ''
    set -euo pipefail

    INSTALL_TARGET="${installPath}"
    INSTALL_LINK="$HOME/.config/rpcs3/dev_hdd0/game"
    RPCS3_DIR="$HOME/.config/rpcs3/dev_hdd0"

    # Ensure RPCS3 data directory exists
    ${pkgs.coreutils}/bin/mkdir -p "$RPCS3_DIR"

    # Check current state
    if [[ -L "$INSTALL_LINK" ]]; then
      # Already a symlink
      CURRENT_TARGET=$(${pkgs.coreutils}/bin/readlink "$INSTALL_LINK")
      if [[ "$CURRENT_TARGET" == "$INSTALL_TARGET" ]]; then
        echo "rpcs3-install: Symlink already correct ($INSTALL_LINK -> $INSTALL_TARGET)"
        exit 0
      fi
      echo "rpcs3-install: Updating symlink..."
      echo "  old target: $CURRENT_TARGET"
      echo "  new target: $INSTALL_TARGET"
      ${pkgs.coreutils}/bin/rm "$INSTALL_LINK"

    elif [[ -d "$INSTALL_LINK" ]]; then
      # Existing local directory - backup and warn
      BACKUP_PATH="$INSTALL_LINK.backup.$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)"

      echo ""
      echo "========================================================================"
      echo "  RPCS3: Existing local install data detected"
      echo "========================================================================"
      echo ""
      echo "  Backing up local install data to:"
      echo "    $BACKUP_PATH"
      echo ""
      echo "  You may want to migrate this data to your shared location:"
      echo "    cp -r $BACKUP_PATH/* $INSTALL_TARGET/"
      echo ""
      echo "========================================================================"
      echo ""

      ${pkgs.coreutils}/bin/mv "$INSTALL_LINK" "$BACKUP_PATH"

    elif [[ -e "$INSTALL_LINK" ]]; then
      echo "rpcs3-install: ERROR: $INSTALL_LINK exists but is not a directory or symlink"
      exit 1
    fi

    # Verify target exists
    if [[ ! -d "$INSTALL_TARGET" ]]; then
      echo "rpcs3-install: Creating target directory: $INSTALL_TARGET"
      ${pkgs.coreutils}/bin/mkdir -p "$INSTALL_TARGET"
    fi

    # Create symlink
    ${pkgs.coreutils}/bin/ln -s "$INSTALL_TARGET" "$INSTALL_LINK"
    echo "rpcs3-install: Symlink created ($INSTALL_LINK -> $INSTALL_TARGET)"
  '';

  # Script to configure VFS games path in vfs.yml
  configureVfsScript = pkgs.writeShellScript "configure-rpcs3-vfs" ''
        set -euo pipefail

        GAMES_PATH="${normalizedGamePath}"
        VFS_FILE="$HOME/.config/rpcs3/vfs.yml"
        RPCS3_DIR="$HOME/.config/rpcs3"

        # Ensure RPCS3 config directory exists
        ${pkgs.coreutils}/bin/mkdir -p "$RPCS3_DIR"

        # Create default vfs.yml if it doesn't exist
        if [[ ! -f "$VFS_FILE" ]]; then
          echo "rpcs3-vfs: Creating default vfs.yml"
          ${pkgs.coreutils}/bin/cat > "$VFS_FILE" << 'EOF'
    $(EmulatorDir): ""
    /dev_hdd0/: $(EmulatorDir)dev_hdd0/
    /dev_hdd1/: $(EmulatorDir)dev_hdd1/
    /dev_flash/: $(EmulatorDir)dev_flash/
    /dev_flash2/: $(EmulatorDir)dev_flash2/
    /dev_flash3/: $(EmulatorDir)dev_flash3/
    /dev_bdvd/: $(EmulatorDir)dev_bdvd/
    /games/: $(EmulatorDir)games/
    /app_home/: ""
    /dev_usb***/:
      /dev_usb000:
        Path: $(EmulatorDir)dev_usb000/
        Serial: ""
        VID: ""
        PID: ""
    EOF
        fi

        # Get current games path
        CURRENT_PATH=$(${pkgs.yq-go}/bin/yq '."/games/"' "$VFS_FILE" 2>/dev/null || echo "")

        if [[ "$CURRENT_PATH" == "$GAMES_PATH" ]]; then
          echo "rpcs3-vfs: Games path already correct (/games/ -> $GAMES_PATH)"
          exit 0
        fi

        echo "rpcs3-vfs: Updating /games/ VFS path..."
        echo "  old: $CURRENT_PATH"
        echo "  new: $GAMES_PATH"

        # Update the /games/ path using yq
        ${pkgs.yq-go}/bin/yq -i '."/games/" = "'"$GAMES_PATH"'"' "$VFS_FILE"

        echo "rpcs3-vfs: VFS configuration updated successfully"
  '';
in {
  config = mkIf (gamingEnabled && rpcs3Enabled) (mkMerge [
    # Savedata symlink for shared saves (if savePath provided)
    (mkIf (savePath != null) {
      home.activation.symlinkRpcs3Savedata = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run ${symlinkSavedataScript}
      '';
    })

    # Install symlink for shared installs/patches (if installPath provided)
    (mkIf (installPath != null) {
      home.activation.symlinkRpcs3Install = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run ${symlinkInstallScript}
      '';
    })

    # VFS games path configuration (if gamePath provided)
    (mkIf (gamePath != null) {
      home.activation.configureRpcs3Vfs = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run ${configureVfsScript}
      '';
    })
  ]);
}
