{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkForce mkDefault;
  system_type = config.mobile.system.type;
in {
  imports = [
    (import "${inputs.mobile-nixos}/lib/configuration.nix" {device = "oneplus-enchilada";})
    (import "${inputs.mobile-nixos}/examples/phosh/phosh.nix")
    ./phosh.nix
  ];

  config = {
    age.secrets."user-simonwjackson-pin".file = ../../../secrets/user-simonwjackson-pin.age;

    mountainous = {
      hardware.cpu.type = "arm";
      user = {
        hashedPasswordFile = mkForce config.age.secrets."user-simonwjackson-pin".path;
      };
      # INFO: mac address appears to change on every boot
      # networking.core.names = [
      #   {
      #     name = "wifi";
      #     mac = "46:59:24:eb:47:6f";
      #   }
      # ];
    };

    services.syncthing = {
      enable = true;
      # key = config.age.secrets.fiji-syncthing-key.path;
      # cert = config.age.secrets.fiji-syncthing-cert.path;
    };

    hardware.bluetooth.enable = true;
    hardware.pulseaudio.enable = mkDefault true; # mkDefault to help out users wanting pipewire

    networking.wireless.enable = false;
    networking.firewall.enable = false;
    powerManagement.enable = true;
    hardware.enableRedistributableFirmware = mkForce true;

    services.xserver.desktopManager.phosh = {
      user = config.mountainous.user.name;
    };

    services.displayManager.autoLogin = {
      user = config.mountainous.user.name;
    };

    # Ensures any rndis config from stage-1 is not clobbered by NetworkManager
    networking.networkmanager.unmanaged = ["rndis0" "usb0"];

    # Setup USB gadget networking in initrd...
    mobile.boot.stage-1.networking.enable = mkDefault true;

    system.stateVersion = "22.11";
  };
}
