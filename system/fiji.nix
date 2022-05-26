{ config, pkgs, modulesPath, lib, ... }:

let
  wifi = {
    mac = "7c:50:79:4f:03:2b";
    name = "wifi";
  };

in
{
  imports = [
    ../modules/hidpi.nix
    ../modules/laptop.nix
    ../modules/workstation.nix
    ../modules/wireguard-client.nix
    ./default.nix
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "fiji"; # Define your hostname.

  environment.systemPackages = with pkgs; [
    cryptsetup
    fuse3 # for nofail option on mergerfs (fuse defaults to fuse2)
    mergerfs
    mergerfs-tools
    snapraid
    nfs-utils
    rpcbind
    lsof
  ];

  services.rpcbind.enable = true;
  services.nfs.server.enable = true;

  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };

  # "/boot" = {
  #   device = "/dev/disk/by-label/boot";
  #   fsType = "vfat";
  # };

    "/run/media/tank" = {
      device = "/dev/disk/by-label/tank";
      # options = [ "defaults" "user" "rw" "utf8" ];
    };

    "/run/media/microsd" = {
      device = "/dev/disk/by-label/microsd";
      # options = [ "defaults" "user" "rw" "utf8" ];
    };

    "/home" = {
      device = "/run/media/tank/home";
      options = [ "bind" ];
    };

    "/tmp" = {
      device = "/run/media/tank/tmp";
      options = [ "bind" ];
    };

    # mergerfs: merge drives
    "/storage" = {
      device = "/run/media/tank/storage:/run/media/microsd";
      # device = "/run/media/tank/storage:/run/media/microsd:/net/192.18.1.123/mnt/user";
      fsType = "fuse.mergerfs";
      options = [
        "defaults"
        "allow_other"
        "use_ino"
        "cache.files=partial"
        "dropcacheonclose=true"
        "category.create=epmfs"
        "nofail"
      ];
    };

    # "/storage/music" = {
    #   device = "/storage/music:/net/192.18.1.123/mnt/user/music";
    #   fsType = "fuse.mergerfs";
    #   options = [
    #     "defaults"
    #     "allow_other"
    #     "use_ino"
    #     "cache.files=partial"
    #     "dropcacheonclose=true"
    #     "category.create=epff"
    #     "nofail"
    #   ];
    # };
  };

  swapDevices = [{
    device = "/dev/disk/by-label/swap"; 
  }];

  networking.interfaces.wlp0s20f3.useDHCP = lib.mkDefault true;

  #powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;






  # Sleep
  # systemd.sleep.extraConfig = ''
  #   # 15min delay
  #   HibernateDelaySec=900
  # '';

  # services.logind.lidSwitch = "suspend-then-hibernate";
  # services.logind.lidSwitchExternalPower = "suspend";

  # services.logind.extraConfig = ''
  #   HandlePowerKey=suspend-then-hibernate
  #   HandleSuspendKey=suspend-then-hibernate
  #   HandleHibernateKey=suspend-then-hibernate
  # '';

  # powerManagement.enable = true;
  # powerManagement.powertop.enable = true;
  # powerManagement.cpuFreqGovernor = lib.mkDefault "balanced";

  # hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.bluetooth.enable = true;

  # Screen tearing
  # https://nixos.org/manual/nixos/unstable/index.html#sec-x11--graphics-cards-intel
  # services.xserver.videoDrivers = [ "modesetting" ];
  # services.xserver.useGlamor = true;

  # services.xserver.videoDrivers = [ "intel" ];
  # services.xserver.deviceSection = ''
  #   Option "DRI" "2"
  #   Option "TearFree" "true"
  # '';

  # services.udev.extraRules = ''
  #   #KERNEL=="wlan*", ATTR{address}=="${wifi.mac}", NAME = "${wifi.name}"
  # '';
  # #KERNEL=="01:03:01:00:01", SUBSYSTEM=="surface_aggregator", RUN+="/usr/bin/chmod 666 /sys/bus/surface_aggregator/devices/01:03:01:00:01/perf_mode"

  # systemd.services.iptsd.enable = false;

  # networking.firewall = {
  #   allowedUDPPorts = [ 51820 ]; # Clients and peers can use the same port, see listenport
  # };

  networking.wireguard.interfaces = {
    mtn = {
      ips = [ "192.18.2.10/32" ];
      privateKey = builtins.getEnv "WIREGUARD_FIJI_PRIVATE";
    };
  };

  services.autofs.enable = true;
  services.autofs.autoMaster = ''
    /net -hosts --timeout=10
  '';

  # services.syncthing = {
  #   overrideDevices = true;
  #   overrideFolders = true;
  #   devices = {
  #     "kuro" = { id = "LXF5VOJ-BJ2ZRJH-PKAMTAV-ERNTHHC-3XJRD4V-G7XLMB3-IXLNZ72-62KONA7"; };
  #     "ushiro" = { id = "QLOZWRC-5K5E43G-EH7OWBS-3ZWQWU3-LAHRHSN-PXEEWXN-RQ7GKKW-UWZOXQQ"; };
  #   };
  # };

  # # TODO: Move to user config
  # services.syncthing = {
  #   enable = true;
  #   user = "simonwjackson";
  #   dataDir = "/storage"; # Default folder for new synced folders
  #   configDir = "/home/simonwjackson/.config/syncthing"; # Folder for Syncthing's settings and keys

  #   folders = {
  #     "documents" = {
  #       path = "/home/simonwjackson/documents";
  #       devices = [ "kuro" ];
  #       # ignorePerms = false;
  #     };

  #     "books" = {
  #       path = "/storage/books";
  #       devices = [ "ushiro" "kuro" ];
  #       # ignorePerms = false;
  #     };

  #   };
  # };
}
