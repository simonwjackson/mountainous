# RPCS3 PS3 Emulator - Home Manager Configuration
#
# Minimal module - just ensures RPCS3 is available.
# Firmware must be installed manually via RPCS3's File → Install Firmware menu.
#
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
  gamingEnabled = osConfig.mountainous.gaming.enable or false;
  rpcs3Enabled = osConfig.mountainous.gaming.rpcs3.enable or false;
in {
  # No home-manager config needed for now - just the package (handled in nixos.nix)
  config = lib.mkIf (gamingEnabled && rpcs3Enabled) {
    # Future: save path symlinks, config management via yq-go, etc.
  };
}
