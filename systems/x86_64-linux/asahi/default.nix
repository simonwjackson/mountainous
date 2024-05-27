# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  pkgs,
  ...
}: {
  backpacker = {
    hardware.cpu.type = "intel";
    hardware.battery.enable = true;
    performance.enable = true;
    profiles.laptop.enable = true;
    networking.core.names = [
      {
        name = "wifi";
        mac = "dc:21:5c:62:68:d0";
      }
    ];
  };

  services.flatpak.enable = true;
  virtualisation.waydroid.enable = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.admin = {
    isNormalUser = true;
    description = "Simon W. Jackson";
    extraGroups = ["networkmanager" "wheel"];
    packages = with pkgs; [
      #  thunderbird
    ];
  };

  # Enable automatic login for the user.
  services.xserver.displayManager.autoLogin.enable = true;
  services.xserver.displayManager.autoLogin.user = "simonwjackson";

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  boot.initrd.availableKernelModules = ["xhci_pci" "thunderbolt" "nvme" "usbhid"];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/4415944d-b656-4a2c-b941-044e0ea907f9";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/FC17-2E24";
    fsType = "vfat";
    options = ["fmask=0022" "dmask=0022"];
  };

  swapDevices = [];

  hardware.sensor.iio.enable = true;

  hardware = {
    opengl.enable = true;
    opengl.driSupport = true;
    opengl.driSupport32Bit = true;

    opengl.extraPackages = with pkgs; [
      intel-media-driver
      vaapiVdpau
      libvdpau-va-gl
    ];
    bluetooth.enable = true;
  };

  system.stateVersion = "23.11"; # Did you read the comment?
}
