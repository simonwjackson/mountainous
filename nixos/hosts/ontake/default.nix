{
  config,
  inputs,
  lib,
  modulesPath,
  outputs,
  pkgs,
  rootPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../../profiles/global
    # ../../profiles/gaming/gaming.nix
    ../../profiles/sound
    ../../profiles/laptop
    ../../profiles/home-manager-xsession.nix
    # ../../profiles/plasma.nix
    ../../profiles/quietboot.nix
    ../../profiles/systemd-boot.nix
    ../../users/simonwjackson/default.nix
  ];

  # age.secrets.yari-syncthing-key.file = rootPath + /secrets/yari-syncthing-key.age;
  # age.secrets.yari-syncthing-cert.file = rootPath + /secrets/yari-syncthing-cert.age;

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "ontake"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  boot.initrd.availableKernelModules = ["xhci_pci" "usb_storage" "sd_mod" "sdhci_acpi"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = [];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/99731bd8-aa68-4b7b-8b24-bfed73b6f6c7";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/92BA-46DD";
    fsType = "vfat";
  };

  swapDevices = [
    {device = "/dev/disk/by-uuid/dfeebec5-4cc3-43d3-9b9b-9613bf311a9a";}
  ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp0s20u1u2.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp1s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

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

  hardware.bluetooth.enable = true;

  # services.syncthing = {
  #   enable = true;
  #   key = config.age.secrets.yari-syncthing-key.path;
  #   cert = config.age.secrets.yari-syncthing-cert.path;

  #   settings.paths = {
  #     gaming-games = "/glacier/snowscape/gaming/games/";
  #     #     documents = "/glacier/snowscape/documents";
  #     #     notes = "/glacier/snowscape/notes";
  #     #     audiobooks = "/glacier/snowscape/audiobooks";
  #     #     books = "/glacier/snowscape/books";
  #     #     comics = "/glacier/snowscape/comics";
  #     #     # code = "/glacier/snowscape/code";
  #     #   };
  #   };

  #   # fileSystems."/home/simonwjackson/documents" = {
  #   #   device = "/glacier/snowscape/documents";
  #   #   options = ["bind"];
  # };

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
