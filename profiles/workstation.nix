{ pkgs, ... }:

{
  imports = [
    ../modules/syncthing.nix
  ];

  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true; # rtkit is optional but recommended

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    jack.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    # jack.enable = true;
  };

  environment.variables.BROWSER = "firefox";

  programs.mosh.enable = true;

  environment.systemPackages = with pkgs; [
    neovim
    wget
    bluez
    bluez-tools
    xsettingsd
    gsettings-desktop-schemas
    kitty # INFO: `sxhkd` can't find kitty without adding here as well
  ];
}

