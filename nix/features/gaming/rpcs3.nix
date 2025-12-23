# RPCS3 PS3 Emulator - Home Manager Configuration
#
# Handles:
# - Symlink management for savedata directory (shared saves across machines)
# - Symlink management for game directory (shared installs/patches across machines)
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

  gamingEnabled = osConfig.mountainous.gaming.enable or false;
  rpcs3Cfg = osConfig.mountainous.gaming.rpcs3 or {};
  rpcs3Enabled = rpcs3Cfg.enable or false;
  savePath = rpcs3Cfg.savePath or null;
  gamePath = rpcs3Cfg.gamePath or null;

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
  symlinkGameScript = pkgs.writeShellScript "symlink-rpcs3-game" ''
    set -euo pipefail

    GAME_TARGET="${gamePath}"
    GAME_LINK="$HOME/.config/rpcs3/dev_hdd0/game"
    RPCS3_DIR="$HOME/.config/rpcs3/dev_hdd0"

    # Ensure RPCS3 data directory exists
    ${pkgs.coreutils}/bin/mkdir -p "$RPCS3_DIR"

    # Check current state
    if [[ -L "$GAME_LINK" ]]; then
      # Already a symlink
      CURRENT_TARGET=$(${pkgs.coreutils}/bin/readlink "$GAME_LINK")
      if [[ "$CURRENT_TARGET" == "$GAME_TARGET" ]]; then
        echo "rpcs3-game: Symlink already correct ($GAME_LINK -> $GAME_TARGET)"
        exit 0
      fi
      echo "rpcs3-game: Updating symlink..."
      echo "  old target: $CURRENT_TARGET"
      echo "  new target: $GAME_TARGET"
      ${pkgs.coreutils}/bin/rm "$GAME_LINK"

    elif [[ -d "$GAME_LINK" ]]; then
      # Existing local directory - backup and warn
      BACKUP_PATH="$GAME_LINK.backup.$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)"

      echo ""
      echo "========================================================================"
      echo "  RPCS3: Existing local game data detected"
      echo "========================================================================"
      echo ""
      echo "  Backing up local game data to:"
      echo "    $BACKUP_PATH"
      echo ""
      echo "  You may want to migrate this data to your shared location:"
      echo "    cp -r $BACKUP_PATH/* $GAME_TARGET/"
      echo ""
      echo "========================================================================"
      echo ""

      ${pkgs.coreutils}/bin/mv "$GAME_LINK" "$BACKUP_PATH"

    elif [[ -e "$GAME_LINK" ]]; then
      echo "rpcs3-game: ERROR: $GAME_LINK exists but is not a directory or symlink"
      exit 1
    fi

    # Verify target exists
    if [[ ! -d "$GAME_TARGET" ]]; then
      echo "rpcs3-game: Creating target directory: $GAME_TARGET"
      ${pkgs.coreutils}/bin/mkdir -p "$GAME_TARGET"
    fi

    # Create symlink
    ${pkgs.coreutils}/bin/ln -s "$GAME_TARGET" "$GAME_LINK"
    echo "rpcs3-game: Symlink created ($GAME_LINK -> $GAME_TARGET)"
  '';
in {
  config = mkIf (gamingEnabled && rpcs3Enabled) (mkMerge [
    # Savedata symlink for shared saves (if savePath provided)
    (mkIf (savePath != null) {
      home.activation.symlinkRpcs3Savedata = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run ${symlinkSavedataScript}
      '';
    })

    # Game symlink for shared installs/patches (if gamePath provided)
    (mkIf (gamePath != null) {
      home.activation.symlinkRpcs3Game = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run ${symlinkGameScript}
      '';
    })
  ]);
}
