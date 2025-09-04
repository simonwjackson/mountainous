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
    # ./web-app.nix
    ./disko.nix
  ];

  environment.systemPackages = with pkgs; [
    mergerfs
    mpvScripts.uosc
    mpv
    git
    ex
    ryzenadj
    obsidian
  ];

  #######################
  # Disable onboard audio
  #######################

  boot.blacklistedKernelModules = ["snd_hda_intel"];
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0b05", ATTR{idProduct}=="1a5c", ATTR{authorized}="0"
  '';

  mountainous = {
    iceberg-array.enable = true;
    impermanence.enable = lib.mkForce false;
    profiles = {
      base.enable = true;
      laptop.enable = true;
      workspace.enable = true;
      gaming.enable = true;
    };
    # networking.core.names = [
    #   {
    #     name = "wifi";
    #     mac = "fc:b0:de:7e:9f:5d";
    #   }
    #   {
    #     name = "eth";
    #     mac = "10:7c:61:4d:e4:11";
    #   }
    # ];
  };

  programs.obs-studio = {
    enable = true;
    enableVirtualCamera = true;
  };

  programs.mosh.enable = true;

  # Enable Thunderbolt support
  services.hardware.bolt.enable = true;

  hardware = {
    cpu = {
      amd = {
        updateMicrocode = true;
        ryzen-smu.enable = true;
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

    # Enable Bluetooth support
    bluetooth.enable = true;
    bluetooth.powerOnBoot = true;
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

  services.xserver.enable = true;
  services.xserver.videoDrivers = ["amdgpu"];

  ###################
  # Misc
  ###################

  fileSystems."/tundra/sleet" = {
    device = "/dev/disk/by-id/usb-Generic_MassStorageClass_000000002958-0:0-part1";
    fsType = "f2fs";
    options = ["noatime" "nofail" "x-systemd.automount" "x-systemd.device-timeout=5"];
  };

  # Enable mountainous Syncthing module with auto-discovery
  mountainous.syncthing = {
    enable = true;
    # Configuration automatically discovered from ./syncthing.nix
    # Certificates automatically configured from agenix secrets
    otherDevices = {
      # Add external devices here as needed
      # Example:
      # "phone" = {
      #   id = "DEVICE-ID-HERE";
      #   shares = ["photos" "documents"];
      # };
    };
  };

  # Enable nginx for meshSidecar validation
  services.nginx = {
    enable = true;
    virtualHosts."localhost" = {
      listen = [
        {
          addr = "127.0.0.1";
          port = 8080;
        }
      ];
      locations."/" = {
        return = "200 'meshSidecar test server on aka'";
        extraConfig = "add_header Content-Type text/plain;";
      };
    };
  };

  system.stateVersion = "24.05";
}
