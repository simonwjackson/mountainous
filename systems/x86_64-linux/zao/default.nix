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
  ];

  # INFO: moved from imports
  boot.loader = {
    systemd-boot = {
      enable = true;
      consoleMode = "max";
    };

    efi.canTouchEfiVariables = true;
  };
  # INFO: end

  mountainous = {
    gaming = {
      core = {
        enable = true;
        isHost = true;
      };

      emulation.enable = true;
      steam.enable = true;
    };

    hardware.battery.enable = true;
    hardware.cpu.type = "intel";
    performance.enable = true;
  };

  # age.secrets.zao-syncthing-key.file = ../../../secrets/zao-syncthing-key.age;
  # age.secrets.zao-syncthing-cert.file = ../../../secrets/zao-syncthing-cert.age;

  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;
  services.xserver.libinput.touchpad.disableWhileTyping = true;
  services.xserver.libinput.touchpad.tapping = true;
  services.geoclue2.enable = true;

  services.logind.lidSwitch = "suspend-then-hibernate";
  services.logind.lidSwitchExternalPower = "suspend";

  services.logind.extraConfig = ''
    HandlePowerKey=suspend-then-hibernate
    HandleSuspendKey=suspend-then-hibernate
    HandleHibernateKey=suspend-then-hibernate
  '';

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "usb_storage"
    "usbhid"
    "sd_mod"
  ];
  boot.kernelModules = [
    "kvm-intel"
    "uinput"
  ];

  environment.systemPackages = with pkgs; [
    nfs-utils
    cifs-utils
    acpi
  ];

  boot.kernelPackages = pkgs.linuxPackages_zen;

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/015bf7c2-0912-4d69-8e08-8e18d1ac287a";
    fsType = "btrfs";
    options = ["subvol=root" "compress=zstd"];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/015bf7c2-0912-4d69-8e08-8e18d1ac287a";
    fsType = "btrfs";
    options = ["subvol=home" "compress=zstd"];
  };

  fileSystems."/glacier/snowscape" = {
    device = "/dev/disk/by-uuid/015bf7c2-0912-4d69-8e08-8e18d1ac287a";
    fsType = "btrfs";
    options = ["subvol=storage" "compress=zstd"];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/015bf7c2-0912-4d69-8e08-8e18d1ac287a";
    fsType = "btrfs";
    options = ["subvol=nix" "compress=zstd" "noatime"];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/D21E-0411";
    fsType = "vfat";
  };

  swapDevices = [{device = "/dev/nvme0n1p2";}];

  # Includes the Wi-Fi and Bluetooth firmware
  hardware.enableRedistributableFirmware = true;

  # hardware.opengl.enable = true;
  hardware.nvidia.prime = {
    offload.enable = lib.mkForce true;
    nvidiaBusId = "PCI:1:0:0";
    intelBusId = "PCI:0:2:0";
  };
  services.xserver.videoDrivers = ["nvidia"];

  # Optionally, you may need to select the appropriate driver version for your specific GPU.
  hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.production;

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  networking.useDHCP = lib.mkDefault true;
  # Use the systemd-boot EFI boot loader.
  # nix.settings.substituters = [ "https://aseipp-nix-cache.global.ssl.fastly.net" ];
  networking.hostName = "zao"; # Define your hostname.

  # services.logind = {
  #   # TODO: only when on battery power
  #   extraConfig = ''
  #     IdleAction=suspend-then-hibernate
  #     IdleActionSec=5m
  #     HandlePowerKey=suspend
  #   '';
  # };
  # systemd.sleep.extraConfig = "HibernateDelaySec=5m";

  # Set your time zone.
  time.timeZone = "America/Chicago";

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the Plasma 5 Desktop Environment.
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.desktopManager.plasma5.enable = true;
  services.xserver.displayManager.autoLogin.enable = true;
  services.xserver.displayManager.autoLogin.user = "simonwjackson";

  # Enable sound.
  sound.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  services.syncthing = {
    enable = true;
    # key = config.age.secrets.fiji-syncthing-key.path;
    # cert = config.age.secrets.fiji-syncthing-cert.path;
    #
  };

  system.stateVersion = "23.05"; # Did you read the comment?
}
