{
  config,
  inputs,
  lib,
  modulesPath,
  options,
  pkgs,
  ...
}: let
  inherit (lib.backpacker) enabled disabled;
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disko.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_zen;
  boot.kernelModules = [
    "kvm-amd"
    "btrfs"
  ];
  boot.resumeDevice = "/dev/nvme0n1p2";
  boot.kernelParams = [
    "resume_offset=9184512"
    "amd_pstate=active"
    # "fbcon=rotate:1"
    # "video=eDP-1:panel_orientation=right_side_up"
  ];
  hardware = {
    i2c.enable = true;
    graphics = {
      enable32Bit = true;
      extraPackages = with pkgs; [
        rocm-opencl-icd
        vaapiVdpau
        rocm-opencl-runtime
        libvdpau-va-gl
      ];
    };
    enableAllFirmware = true;
    cpu.amd = {
      updateMicrocode = true;
      ryzen-smu.enable = true;
    };
  };

  backpacker = {
    hardware = {
      bluetooth.enable = true;
      battery.enable = true;
      cpu.type = "amd";
    };

    profiles.laptop = enabled;
    syncthing = {
      enable = false;
    };
    # boot = disabled;
    gaming = {
      core = {
        enable = true;
      };
      # emulation = {
      #   enable = true;
      #   gen-7 = true;
      #   gen-8 = true;
      # };
      steam = enabled;
    };
    desktops = {
      plasma = {
        enable = true;
        autoLogin = false;
      };
    };
    networking.core.names = [
      {
        name = "wifi";
        mac = "10:6f:d9:29:8e:97";
      }
    ];

    # BUG: ccache broken
    performance = disabled;
  };

  networking.firewall.enable = false;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.enableHidpi = false;
  # services.displayManager.sessionCommands = ''
  #   export QT_SCALE_FACTOR=1.5
  # '';
  services.desktopManager.plasma6.enable = true;
  services.displayManager.defaultSession = "plasma";
  services.displayManager.sddm.wayland.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = ["wheel"]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [
      ryzenadj
      gamescope
      gamemode
      moonlight-qt
      mangohud
      proton-ge-custom
    ];
  };

  system.stateVersion = "24.05";

  services.fprintd.enable = true;
  nixpkgs.overlays = [
    (final: prev: {
      libfprint = prev.libfprint.overrideAttrs (oldAttrs: {
        version = "git";
        src = final.fetchFromGitHub {
          owner = "ericlinagora";
          repo = "libfprint-CS9711";
          rev = "c242a40fcc51aec5b57d877bdf3edfe8cb4883fd";
          sha256 = "sha256-WFq8sNitwhOOS3eO8V35EMs+FA73pbILRP0JoW/UR80=";
        };
        nativeBuildInputs =
          oldAttrs.nativeBuildInputs
          ++ [
            final.opencv
            final.cmake
            final.doctest
          ];
      });
    })
  ];

  security.pam.services.sddm.fprintAuth = true;

  ###### HARDWARE

  boot.initrd.availableKernelModules = ["nvme" "xhci_pci" "usbhid" "uas" "sd_mod" "rtsx_pci_sdmmc"];
  boot.initrd.kernelModules = [];
  boot.extraModulePackages = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
