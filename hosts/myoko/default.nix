# myoko — ASUS Zenbook A16 (UX3607OA), Snapdragon X2 Elite Extreme.
#
# Scaffold only. The machine has not booted Linux here yet, so treat every
# runtime claim in this directory as untested. hardware.nix lists the Glymur
# enablement work that is still open.
{...}: {
  imports = [
    ./disko.nix
    ./hardware.nix
  ];

  networking.hostName = "myoko";
  time.timeZone = "America/Denver";

  nixpkgs.config.allowUnfree = true;

  mountainous = {
    presets = {
      core.enable = true;
      desktop.enable = true;
      portable.enable = true;
      workstation.enable = true;
    };

    features = {
      device = {
        role = "portable";
        capabilities = {
          battery = true;
          formFactor = "laptop";
          # ASUS lists the UX3607OA panel as touch. The devicetree describes a
          # touchscreen node that upstream marks untested.
          touchscreen = true;
        };
      };

      # presets/desktop turns Hyprland on by default. This host runs niri
      # instead, and the niri module asserts that only one of them is enabled.
      hyprland.enable = false;
      niri.enable = true;

      bluetooth.enable = true;
      firefox = {
        enable = true;
        cascade.enable = true;
      };
    };
  };

  system.stateVersion = "26.05";
}
