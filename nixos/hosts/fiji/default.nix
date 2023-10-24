{ config, pkgs, inputs, lib, modulesPath, ... }: {
  imports = [
    ../../profiles/global
    ../../profiles/sound
    ../../profiles/laptop
    # ../../profiles/plasma.nix
    ../../profiles/quietboot.nix
    ../../profiles/systemd-boot.nix
    ../../users/simonwjackson/default.nix
  ];

  age.secrets.fiji-syncthing-key.file = ../../../secrets/fiji-syncthing-key.age;
  age.secrets.fiji-syncthing-cert.file = ../../../secrets/fiji-syncthing-cert.age;

  xdg.portal = {
    enable = true;

    extraPortals = with pkgs; [
      xdg-desktop-portal-kde
    ];
  };

  # programs.hyprland = {
  #   enable = true;
  #   package = inputs.hyprland.packages.${pkgs.system}.hyprland;
  # };

  services.xserver = {
    enable = true;
    desktopManager = {
      xfce.enable = true;
    };

    windowManager.icewm.enable = true;

    displayManager.defaultSession = "xfce";
  };

  boot.supportedFilesystems = [ "xfs" ];
  networking.hostName = "fiji";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # FIXME
  # services.vscode-server.enable = true;

  services.vpn-proxy = {
    enable = true;
    host = "100.76.86.139";
    localUser = "simonwjackson";
    remoteUser = "sjackson217";
    localPort = 9999;
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];

  # HACK: using `fileSystems` with bcachefs does not seem to work yet.
  # systemd.services.mountSnowscape = {
  #   script = ''
  #     install -d -o simonwjackson -g users -m 770 /glacier/snowscape
  #      ${pkgs.util-linux}/bin/mountpoint -q /glacier/snowscape || ${pkgs.mount}/bin/mount -t bcachefs /dev/nvme0n1p4:/dev/sda1 /glacier/snowscape
  #   '';
  #   wantedBy = [ "multi-user.target" ];
  #   serviceConfig = {
  #     Type = "oneshot";
  #   };
  # };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/59571b0c-3ed8-4650-96e4-82e72a1af75e";
    fsType = "btrfs";
    options = [ "subvol=root" "compress=zstd" ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/59571b0c-3ed8-4650-96e4-82e72a1af75e";
    fsType = "btrfs";
    options = [ "subvol=home" "compress=zstd" ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/59571b0c-3ed8-4650-96e4-82e72a1af75e";
    fsType = "btrfs";
    options = [ "subvol=nix" "compress=zstd" "noatime" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/1483-B118";
    fsType = "vfat";
  };

  fileSystems."/glacier/snowscape" = {
    device = "/dev/disk/by-uuid/7f8f9daa-affe-47c9-8555-3373626f1180";
    fsType = "xfs";
  };

  swapDevices = [{
    device = "/dev/disk/by-label/swap";
  }];

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  hardware.bluetooth.enable = true;

  services.syncthing = {
    enable = true;
    key = config.age.secrets.fiji-syncthing-key.path;
    cert = config.age.secrets.fiji-syncthing-cert.path;

    settings.paths = {
      documents = "/glacier/snowscape/documents";
      notes = "/glacier/snowscape/notes";
      audiobooks = "/glacier/snowscape/audiobooks";
      books = "/glacier/snowscape/books";
      comics = "/glacier/snowscape/comics";
      # code = "/glacier/snowscape/code";
    };
  };

  fileSystems."/home/simonwjackson/documents" = {
    device = "/glacier/snowscape/documents";
    options = [ "bind" ];
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "balanced";

  services.udev.extraRules = ''
    KERNEL=="wlan*", ATTR{address}=="d4:d8:53:90:2b:6c", NAME = "wifi"
  '';

  environment.systemPackages = with pkgs; [
    yuzu
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
