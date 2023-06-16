{ config, pkgs, modulesPath, lib, ... }:

let
  wifi = {
    mac = "c4:23:60:9f:f2:1d";
    name = "wifi";
  };

in
{
  imports = [
    ../modules/hidpi.nix
    ../modules/laptop.nix
    ../modules/workstation.nix
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
    # rpcbind
    # lsof
  ];

  # services.rpcbind.enable = true;
  services.nfs.server.enable = true;

  #boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelPackages = pkgs.linuxPackages_6_2;
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

    "/run/media/nvme" = {
      device = "/dev/disk/by-label/nvme";
      # options = [ "defaults" "user" "rw" "utf8" ];
    };

    "/run/media/microsd" = {
      device = "/dev/disk/by-label/microsd";
      # options = [ "defaults" "user" "rw" "utf8" ];
    };

    "/home" = {
      device = "/run/media/nvme/home";
      options = [ "bind" ];
    };

    "/tmp" = {
      device = "/run/media/nvme/tmp";
      options = [ "bind" ];
    };

    # mergerfs: merge drives
    "/tank" = {
      device = "/run/media/nvme:/run/media/microsd";
      fsType = "fuse.mergerfs";
      options = [
        "defaults"
        "allow_other"
        "use_ino"
        "cache.files=partial"
        "dropcacheonclose=true"
        "category.create=epff"
        "nofail"
      ];
    };

    "/storage" = {
      device = "/tank/storage:/net/192.18.1.123/mnt/user";
      fsType = "fuse.mergerfs";
      options = [
        "defaults"
        "allow_other"
        "use_ino"
        "cache.files=partial"
        "dropcacheonclose=true"
        "category.create=epff"
        "nofail"
      ];
    };
  };

  swapDevices = [{
    device = "/dev/disk/by-label/swap";
  }];

  networking.interfaces.wifi.useDHCP = lib.mkDefault true;

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Sleep
  systemd.sleep.extraConfig = ''
    # 15min delay
    HibernateDelaySec=900
  '';

  services.logind.lidSwitch = "suspend-then-hibernate";
  services.logind.lidSwitchExternalPower = "suspend";

  services.logind.extraConfig = ''
    HandlePowerKey=suspend-then-hibernate
    HandleSuspendKey=suspend-then-hibernate
    HandleHibernateKey=suspend-then-hibernate
  '';

  powerManagement.enable = true;
  powerManagement.powertop.enable = true;
  powerManagement.cpuFreqGovernor = lib.mkDefault "balanced";

  # hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.bluetooth.enable = true;

  # Screen tearing
  # https://nixos.org/manual/nixos/unstable/index.html#sec-x11--graphics-cards-intel
  services.xserver.videoDrivers = [ "modesetting" ];
  # services.xserver.useGlamor = true;

  services.udev.extraRules = ''
    KERNEL=="wlan*", ATTR{address}=="${wifi.mac}", NAME = "${wifi.name}"

    KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
  '';

  # 2nd udev rule for sunshine

  # systemd.services.iptsd.enable = false;

  services.avahi = {
    enable = true;
    nssmdns = true;
    wideArea = true;
  };

  networking.firewall = {
    enable = false;
    allowedUDPPorts = [ 51820 ]; # Clients and peers can use the same port, see listenport
    allowedTCPPorts = [ 24800 ];
  };

  services.autofs.enable = true;
  services.autofs.autoMaster = ''
    /net -hosts --timeout=10
  '';

  services.syncthing = {
    overrideDevices = true;
    overrideFolders = true;
    devices = {
      kuro.id = "4YUE3JH-CUR4TTS-RVTNUHZ-2HDENB3-FH3VWIJ-TMCW3X5-JSPKLXB-H2QUEAP";
      ushiro.id = builtins.getEnv "SYNCTHING_USHIRO_ID";
      pixel.id = "3JIMY3T-PU4S3LS-UOIFSEY-2XJ52XF-J6HPOIW-TZTSDBB-AA3K2KB-ULNE3AZ";
      ultra.id = "DWTWS42-OIDSJUJ-UGSE6BV-Q2Z3YWB-IKB3SHE-DKRFXC7-XLMR2Z5-MD27BAJ";
    };
  };

  # TODO: Move to user config
  services.syncthing = {
    enable = true;
    user = "simonwjackson";
    dataDir = "/tank"; # Default folder for new synced folders
    configDir = "/home/simonwjackson/.config/syncthing";

    extraFlags = [
      "--no-default-folder"
    ];

    extraOptions = {
      ignores = {
        "line" = [
          "**/node_modules"
          "**/build"
          "**/cache"
        ];
      };
    };

    folders = {
      "documents" = {
        path = "/home/simonwjackson/documents";
        devices = [ "kuro" "pixel" "ultra" ];
        # ignorePerms = false;
      };

      "audiobooks" = {
        path = "/tank/storage/audiobooks";
        devices = [ "kuro" ];
        # ignorePerms = false;
      };

      "books" = {
        path = "/tank/storage/books";
        devices = [ "kuro" "pixel" "ultra" ];
        # ignorePerms = false;
      };

      "music" = {
        path = "/tank/storage/music";
        devices = [ "kuro" ];
        # ignorePerms = false;
      };

      "code" = {
        path = "/home/simonwjackson/code";
        devices = [ "ushiro" ];
      };
    };
  };

  services.flatpak.enable = true;

  services.printing.enable = true;
  services.printing.drivers = with pkgs; [ brlaser ];

  services.mpd = {
    enable = true;
    user = "simonwjackson";
    group = "users";
    musicDirectory = "/tank/storage/music";
    extraConfig = ''
      audio_output {
        type "pulse"
        name "Pulseaudio"
        server "127.0.0.1" # add this line - MPD must connect to the local sound server
      }
    '';

    # Optional:
    network.listenAddress = "127.0.0.1"; # if you want to allow non-localhost connections
    startWhenNeeded = true; # systemd feature: only start MPD service upon connection to its socket
  };
}