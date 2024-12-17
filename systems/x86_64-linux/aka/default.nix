{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}: let
  inherit (lib.mountainous) enabled disabled;
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./sunshine.nix
    ./web-app.nix
    ./disko.nix
  ];

  # fileSystems."/run/media/walkman" = {
  #   device = "/dev/disk/by-uuid/FE19-B029";
  #   fsType = "exfat";
  #   options = [
  #     "uid=333"
  #     "gid=333"
  #     "fmask=113"
  #     "dmask=002"
  #     "defaults"
  #     "nofail"
  #     "x-systemd.automount"
  #   ];
  # };
  #
  # fileSystems."/run/media/mazda-media" = {
  #   device = "/dev/disk/by-uuid/3833-6538";
  #   fsType = "exfat";
  #   options = [
  #     "uid=333"
  #     "gid=333"
  #     "fmask=113"
  #     "dmask=002"
  #     "defaults"
  #     "nofail"
  #     "x-systemd.automount"
  #   ];
  # };

  # services.youtube-dl-subscriptions = {
  #   enable = true;
  #   interval = "*:0/30";
  #   user = "simonwjackson";
  #   group = "users";
  #   dataDir = "/snowscape/videos/youtube";
  #
  #   extraArgs = [
  #     "--playlist-reverse"
  #     "--playlist-end 5"
  #     "--write-auto-sub"
  #     "--sub-format vtt"
  #     "--sponsorblock-remove sponsor,selfpromo,interaction,intro,outro"
  #   ];
  # };

  environment.systemPackages = with pkgs; [
    mergerfs
    mpvScripts.uosc
    mpv
    # gamescope
  ];

  #######################
  # Disable onboard audio
  #######################

  boot.blacklistedKernelModules = ["snd_hda_intel"];
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0b05", ATTR{idProduct}=="1a5c", ATTR{authorized}="0"
  '';

  mountainous = {
    bluetooth-tether = {
      enable = false;
      devices = [
        {
          name = "usu";
          macAddress = "F0:05:1B:E2:42:8C";
        }
      ];
    };
    boot = disabled;
    gaming = {
      gamepad-proxy = enabled;
      core = {
        enable = true;
        isHost = false;
      };
      emulation = {
        enable = true;
        gen-7 = true;
        gen-8 = true;
        gamingDir = "/snowscape/gaming";
        saves = "/snowscape/gaming/profiles/simonwjackson/progress/saves";
      };
      steam = {enable = true;};
    };
    hardware.cpu.type = "amd";
    networking.core.names = [
      {
        name = "wifi";
        mac = "fc:b0:de:7e:9f:5d";
      }
      {
        name = "eth";
        mac = "10:7c:61:4d:e4:11";
      }
    ];
    profiles.workstation = enabled;
    snowscape = {
      enable = true;
      glacier = "unzen";
      paths = [
        "/snowscape"
      ];
    };
  };

  hardware = {
    cpu = {
      amd = {
        updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      };
    };
    graphics = {
      enable32Bit = true;
      extraPackages = with pkgs; [
        amdvlk
      ];
      extraPackages32 = with pkgs; [
        driversi686Linux.amdvlk
      ];
    };
  };

  environment.etc."mdadm.conf".text = ''
    MAILADDR root@localhost
    PROGRAM /run/current-system/sw/bin/mdadm-monitor
  '';

  boot = {
    swraid.enable = true;
    extraModulePackages = [];
    initrd = {
      availableKernelModules = [
        "ahci"
        "nvme"
        "sd_mod"
        "uas"
        "usb_storage"
        "usbhid"
        "xhci_pci"
      ];
      kernelModules = ["dm-snapshot" "amdgpu" "i2c-dev"];
    };
    kernelModules = ["kvm-amd" "tun"];
    kernelPackages = pkgs.linuxPackages_zen;
    loader = {
      efi = {
        canTouchEfiVariables = false;
        efiSysMountPoint = "/boot";
      };
      grub = {
        enable = true;
        devices = [
          "/dev/disk/by-id/usb-Lexar_USB_Flash_Drive_0374219080022724-0:0"
          "/dev/disk/by-id/usb-Lexar_USB_Flash_Drive_0374219080022992-0:0"
        ];
        efiSupport = true;
        efiInstallAsRemovable = true;
        copyKernels = true;
        fsIdentifier = "uuid";
      };
    };
  };

  ##########################################################

  boot.binfmt.emulatedSystems = ["aarch64-linux"];

  ##########################################################

  services.xserver.enable = true;
  services.xserver.videoDrivers = ["amdgpu"];

  system.stateVersion = "24.05";
}
