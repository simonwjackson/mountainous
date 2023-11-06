{
  config,
  pkgs,
  inputs,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    ../../profiles/global
    ../../profiles/gaming/gaming.nix
    ../../profiles/sound
    ../../profiles/laptop
    ../../profiles/home-manager-xsession.nix
    # ../../profiles/plasma.nix
    ../../profiles/quietboot.nix
    ../../profiles/systemd-boot.nix
    ../../users/simonwjackson/default.nix
  ];

  age.secrets.fiji-syncthing-key.file = ../../../secrets/fiji-syncthing-key.age;
  age.secrets.fiji-syncthing-cert.file = ../../../secrets/fiji-syncthing-cert.age;

  networking.hostName = "yari";

  services.flatpak.enable = true;

  system.activationScripts.flatpakConfig = {
    text = ''
      ${pkgs.flatpak}/bin/flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
      ${pkgs.flatpak}/bin/flatpak update --assumeyes com.valvesoftware.Steam.CompatibilityTool.Proton-GE || ${pkgs.flatpak}/bin/flatpak install --assumeyes com.valvesoftware.Steam.CompatibilityTool.Proton-GE
      ${pkgs.flatpak}/bin/flatpak update --assumeyes com.valvesoftware.Steam || ${pkgs.flatpak}/bin/flatpak install --assumeyes com.valvesoftware.Steam
    '';
  };

  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;

    extraPortals = with pkgs; [
      xdg-desktop-portal-kde
    ];
  };

  boot.supportedFilesystems = ["xfs"];
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.availableKernelModules = ["xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  hardware.bluetooth.enable = true;

  # services.syncthing = {
  #   enable = true;
  #   key = config.age.secrets.fiji-syncthing-key.path;
  #   cert = config.age.secrets.fiji-syncthing-cert.path;
  #
  #   settings.paths = {
  #     documents = "/glacier/snowscape/documents";
  #     notes = "/glacier/snowscape/notes";
  #     audiobooks = "/glacier/snowscape/audiobooks";
  #     books = "/glacier/snowscape/books";
  #     comics = "/glacier/snowscape/comics";
  #     # code = "/glacier/snowscape/code";
  #   };
  # };
  #
  # fileSystems."/home/simonwjackson/documents" = {
  #   device = "/glacier/snowscape/documents";
  #   options = ["bind"];
  # };

  # powerManagement.cpuFreqGovernor = lib.mkDefault "balanced";

  # services.udev.extraRules = ''
  #   KERNEL=="wlan*", ATTR{address}=="d4:d8:53:90:2b:6c", NAME = "wifi"
  # '';

  environment.systemPackages = with pkgs; [
    moonlight-qt
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
