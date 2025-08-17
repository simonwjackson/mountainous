# Example configuration showing how to enable the mountainous.syncthing module in aka
{
  mountainous.syncthing = {
    enable = true;
    user = "simonwjackson";
    
    # External devices (phones, tablets, etc.)
    otherDevices = {
      "pixel-phone" = {
        id = "PIXEL-DEVICE-ID-HERE";
        shares = ["photos" "documents" "screenshots"];
      };
      "ipad" = {
        id = "IPAD-DEVICE-ID-HERE";
        shares = ["documents" "media"];
        addresses = ["dynamic"]; # or specific IPs
      };
    };
    
    # Optional: Custom settings
    guiAddress = "127.0.0.1:8384";
    disableDefaultFolder = true;
  };
  
  # The module will automatically:
  # 1. Discover this system's syncthing.nix configuration
  # 2. Find other systems with syncthing.nix files
  # 3. Build device network based on shared folders
  # 4. Create .stignore files from whitelist/blacklist patterns
  # 5. Set up certificates from agenix secrets
}