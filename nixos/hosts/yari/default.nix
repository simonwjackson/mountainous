{
  config,
  pkgs,
  inputs,
  lib,
  modulesPath,
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

  # age.secrets.fiji-syncthing-key.file = ../../../secrets/fiji-syncthing-key.age;
  # age.secrets.fiji-syncthing-cert.file = ../../../secrets/fiji-syncthing-cert.age;

  networking.hostName = "yari";

  boot.initrd.availableKernelModules = ["nvme" "xhci_pci" "thunderbolt" "usbhid" "uas" "sd_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-amd"];
  boot.extraModulePackages = [];
  boot.kernelPackages = pkgs.linuxPackages_zen;

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/4fa1f4ac-1867-42ad-ad55-4b0be2398ac0";
    fsType = "btrfs";
    options = ["subvol=root" "compress=zstd"];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/4fa1f4ac-1867-42ad-ad55-4b0be2398ac0";
    fsType = "btrfs";
    options = ["subvol=home" "compress=zstd"];
  };

  fileSystems."/glacier/snowscape" = {
    device = "/dev/disk/by-uuid/4fa1f4ac-1867-42ad-ad55-4b0be2398ac0";
    fsType = "btrfs";
    options = ["subvol=snowscape" "compress=zstd"];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/4fa1f4ac-1867-42ad-ad55-4b0be2398ac0";
    fsType = "btrfs";
    options = ["subvol=nix" "compress=zstd" "noatime"];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/572D-7C8E";
    fsType = "vfat";
  };

  swapDevices = [
    {
      device = "/dev/nvme0n1p2";
    }
  ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp2s0.useDHCP = lib.mkDefault true;

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

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

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

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
