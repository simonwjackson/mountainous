{
  config,
  lib,
  pkgs,
  modulesPath,
  inputs,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    # inputs.nix-gaming.nixosModules.steamCompat

    ../../profiles/global
    ../../profiles/sound
    # ../../profiles/systemd-boot.nix
    ../../users/simonwjackson
    # # ../../modules/syncthing.nix
    ../../profiles/gaming/gaming-host.nix
  ];

  services.auto-cpufreq.enable = true;
  services.power-profiles-daemon.enable = false;
  services.input-remapper.enable = false;
  services.thermald.enable = true;
  virtualisation.waydroid.enable = true;
  programs.xwayland.enable = true;
  programs.ccache.enable = true;

  systemd.targets.ac = {
    conflicts = ["battery.target"];
    description = "On AC power";
    unitConfig = {DefaultDependencies = "false";};
  };

  systemd.targets.battery = {
    conflicts = ["ac.target"];
    description = "On battery power";
    unitConfig = {DefaultDependencies = "false";};
  };

  # systemd.services.power-maximum-tdp = {
  #   description = "Change TDP to maximum TDP when on AC power";
  #   wantedBy = ["ac.target"];
  #   unitConfig = {RefuseManualStart = true;};
  #   serviceConfig = {
  #     Type = "oneshot";
  #     ExecStart = "${pkgs.ryzenadj}/bin/ryzenadj --stapm-limit=28000 --fast-limit=28000 --slow-limit=28000 --tctl-temp=90";
  #   };
  # };
  #
  # systemd.services.power-saving-tdp = {
  #   description = "Change TDP to power saving TDP when on battery power";
  #   wantedBy = ["battery.target"];
  #   unitConfig = {RefuseManualStart = true;};
  #   serviceConfig = {
  #     Type = "oneshot";
  #     ExecStart = "${pkgs.ryzenadj}/bin/ryzenadj --stapm-limit=3000 --fast-limit=3000 --slow-limit=3000 --tctl-temp=90";
  #   };
  # };

  systemd.services.powertop = {
    # description = "Auto-tune Power Management with powertop";
    unitConfig = {RefuseManualStart = true;};
    wantedBy = ["battery.target" "ac.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.powertop}/bin/powertop --auto-tune";
    };
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", KERNEL=="ACAD", ATTR{online}=="1", RUN+="${pkgs.systemd}/bin/systemctl start ac.target"
    SUBSYSTEM=="power_supply", KERNEL=="ACAD", ATTR{online}=="0", RUN+="${pkgs.systemd}/bin/systemctl start battery.target"
  '';

  powerManagement = {
    enable = true;
    cpuFreqGovernor = pkgs.lib.mkDefault "powersave";
  };

  # programs.steam = {
  #   gamescopeSession = {
  #     enable = true;
  #     args = ["--rt"];
  #     env = {ENABLE_GAMESCOPE_WSI = "1";};
  #     #steamArgs = [ "-pipewire-dmabuf" ];
  #   };
  #   enable = true;
  #   remotePlay.openFirewall = true;
  # };

  # programs.gamescope = {
  #   env = {
  #     ENABLE_GAMESCOPE_WSI = "1";
  #     __GLX_VENDOR_LIBRARY_NAME = "mesa";
  #   };
  #   enable = true;
  #   # package = pkgs.gamescope_git;
  #   args = ["--rt"];
  # };

  zramSwap.enable = true;
  services.resolved.enable = true;
  console = {
    earlySetup = true;
    font = "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz";
    packages = with pkgs; [terminus_font];
    keyMap = "pl2";
  };

  # a shell daemon created to manage processes' IO and CPU priorities, with community-driven set of rule
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
  };

  programs.dconf.enable = true;

  environment.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1";
  };

  xdg.portal.enable = true;

  # Switch controllers
  services.joycond.enable = true;

  environment.systemPackages = with pkgs; [
    undervolt
    mergerfs
    neovim
    git
    moonlight-qt
    kitty
  ];

  boot.initrd.availableKernelModules = ["nvme" "xhci_pci" "thunderbolt" "usbhid" "usb_storage" "sd_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-amd"];
  boot.extraModulePackages = [];
  # boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelPackages = pkgs.linuxPackages_zen;

  # *might* fix white/flashing screens
  # kernelParams = ["amdgpu.sg_display=0"];
  # WARNING: promises better energy efficency but This *might* cause lower fps. kernel 6.3 or higher
  # kernelParams = [ "amd_pstate=active" ];
  boot.kernelParams = [
    "fbcon=rotate:1"
    "video=eDP-1:panel_orientation=right_side_up"
  ];

  # Required for grub to properly display the boot menu.
  boot.loader.grub.gfxmodeEfi = lib.mkDefault "1080x1920x32";

  # services.xserver.deviceSection = ''
  #   Option "TearFree" "true"
  # '';

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/899ac974-c586-4021-8509-10313660cc3f";
    fsType = "btrfs";
    options = ["subvol=root" "discard=async" "compress=zstd"];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/899ac974-c586-4021-8509-10313660cc3f";
    fsType = "btrfs";
    options = ["subvol=home" "discard=async" "compress=zstd"];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/899ac974-c586-4021-8509-10313660cc3f";
    fsType = "btrfs";
    options = ["subvol=nix" "compress=zstd" "discard=async" "noatime"];
  };

  fileSystems."/glacier/blizzard" = {
    device = "/dev/disk/by-uuid/899ac974-c586-4021-8509-10313660cc3f";
    fsType = "btrfs";
    options = ["subvol=blizzard" "discard=async" "compress=zstd"];
  };

  fileSystems."/glacier/sleet" = {
    device = "/dev/disk/by-label/sleet";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/nvme0n1p1";
    # device = "/dev/disk/by-uuid/12CE-A600";
    fsType = "vfat";
  };

  fileSystems."/glacier/snowscape" = {
    # depends = ["/glacier/blizzard" "/glacier/sleet"];
    depends = ["/glacier/blizzard"];
    device = "/glacier/blizzard";
    # device = "/glacier/blizzard:/glacier/sleet";
    fsType = "fuse.mergerfs";
    options = [
      "minfreespace=1G"
      "category.create=ff"
      "category.search=ff"
      "attr_timeout=60"
      "ignorepponrename=true"
      "moveonenospc=true"
    ];
  };

  swapDevices = [
    {
      device = "/dev/disk/by-uuid/3873bb31-f29c-4a3b-98f9-10f2334c55a8";
    }
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "kita";
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  services.xserver.enable = true;
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.displayManager.autoLogin.enable = true;
  services.xserver.displayManager.autoLogin.user = "simonwjackson";
  services.xserver.desktopManager.plasma5.enable = true;
  services.xserver.displayManager.defaultSession = "plasmawayland";
  services.xserver.displayManager.sddm.wayland.enable = true;

  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = [
      "adbusers"
      "audio"
      "input"
      "libvirtd"
      "lp"
      "networkmanager"
      "scanner"
      "video"
      "wheel"
    ];
    packages = with pkgs; [
      firefox
      neovim
      git
      tmux
      mosh
    ];
  };

  services.openssh.enable = true;
  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware = {
    sensor.iio.enable = true;
    opengl = {
      driSupport = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [
        rocm-opencl-icd
        vaapiVdpau
        rocm-opencl-runtime
        libvdpau-va-gl
      ];
    };
    enableAllFirmware = true;
    bluetooth = {enable = true;};
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    steam-hardware.enable = true;
  };

  services.geoclue2.enable = true;

  powerManagement.powertop.enable = true;

  # services.logind.lidSwitch = "suspend-then-hibernate";
  # services.logind.lidSwitchExternalPower = "suspend";
  #
  # services.logind.extraConfig = ''
  #   HandlePowerKey=suspend-then-hibernate
  #   HandleSuspendKey=suspend-then-hibernate
  #   HandleHibernateKey=suspend-then-hibernate
  # '';
  #
  # systemd.sleep.extraConfig = "HibernateDelaySec=5m";

  system.stateVersion = "23.11"; # Did you read the comment?
}
#   # services.logind = {
#   #   # TODO: only when on battery power
#   #   extraConfig = ''
#   #     IdleAction=suspend-then-hibernate
#   #     IdleActionSec=5m
#   #   '';
#   # };
#
#   # # services.syncthing = {
#   # #   dataDir = "/home/simonwjackson"; # Default folder for new synced folders
#   # #
#   # #   folders = {
#   # #     code.path = "/home/simonwjackson/code";
#   # #     documents.path = "/glacier/snowscape/documents";
#   # #     gaming-games.path = "/glacier/snowscape/gaming/games";
#   # #     gaming-launchers.path = "/glacier/snowscape/gaming/launchers";
#   # #     gaming-profiles.path = "/glacier/snowscape/gaming/profiles";
#   # #     gaming-systems.path = "/glacier/snowscape/gaming/systems";
#   # #     taskwarrior.path = "/home/simonwjackson/.local/share/task";
#   # #
#   # #     code.devices = [ "fiji" "unzen" "yari" ];
#   # #     documents.devices = [ "fiji" "unzen" "zao" ];
#   # #     gaming-games.devices = [ "fiji" "unzen" "yari" "zao" ];
#   # #     gaming-launchers.devices = [ "fiji" "unzen" "zao" ];
#   # #     gaming-profiles.devices = [ "fiji" "usu" "unzen" "yari" "zao" ];
#   # #     gaming-systems.devices = [ "fiji" "unzen" "zao" ];
#   # #     taskwarrior.devices = [ "fiji" "unzen" "zao" ];
#   # #
#   # #     gaming-profiles.versioning = {
#   # #       type = "staggered";
#   # #       params = {
#   # #         cleanInterval = "3600";
#   # #         maxAge = "31536000";
#   # #       };
#   # #     };
#   # #   };
#   # # };
# }
