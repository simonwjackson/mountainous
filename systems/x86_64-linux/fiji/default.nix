{
  config,
  inputs,
  lib,
  modulesPath,
  options,
  pkgs,
  ...
}: {
  age = {
    identityPaths =
      options.age.identityPaths.default
      ++ [
        # TODO: Pull this value from somewhere else in the config
        "/home/simonwjackson/.ssh/agenix"
      ];
  };

  # START: From old modules
  boot.loader = {
    systemd-boot = {
      enable = true;
      consoleMode = "max";
    };

    efi.canTouchEfiVariables = true;
  };
  console = {
    useXkbConfig = true;
    earlySetup = false;
  };

  programs.hyprland.enable = true;
  programs.hyprland.xwayland.enable = true;

  # services.getty.autologinUser = "simonwjackson";
  # services.getty.tty1.autologin = true;

  services.libinput.enable = true;
  services.libinput.touchpad.disableWhileTyping = true;
  services.libinput.touchpad.tapping = true;
  services.geoclue2.enable = true;

  powerManagement.enable = true;
  powerManagement.powertop.enable = true;

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
    IdleAction=hibernate
    IdleActionSec=15min
  '';
  services = {
    xserver.enable = true;
    displayManager.autoLogin.user = "simonwjackson";
    displayManager.defaultSession = "home-manager";
    # We need to create at least one session for auto login to work
    xserver.desktopManager.session = [
      {
        name = "home-manager";
        start = ''
          ${pkgs.runtimeShell} $HOME/.hm-xsession &
          waitPID=$!
        '';
      }
    ];
  };

  # END: From old modules

  mountainous.laptop.enable = true;

  age.secrets.game-collection-sync.file = ../../../secrets/game-collection-sync.age;
  age.secrets.fiji-syncthing-key.file = ../../../secrets/fiji-syncthing-key.age;
  age.secrets.fiji-syncthing-cert.file = ../../../secrets/fiji-syncthing-cert.age;

  services.flatpak.enable = true;

  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;

    extraPortals = with pkgs; [
      xdg-desktop-portal-kde
    ];
  };

  boot.supportedFilesystems = ["xfs"];
  networking.hostName = "fiji";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.availableKernelModules = ["xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];

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

  systemd.services.fixSamsungGalaxyBook3Speakers = {
    path = [pkgs.alsa-tools];
    script = builtins.readFile ./fix-audio.sh;
    wantedBy = ["multi-user.target" "post-resume.target"];
    after = ["multi-user.target" "post-resume.target"];
    serviceConfig = {
      Type = "oneshot";
    };
  };

  fileSystems."/" = {
    label = "root";
    fsType = "btrfs";
    options = ["subvol=root" "compress=zstd"];
  };

  fileSystems."/home" = {
    label = "root";
    fsType = "btrfs";
    options = ["subvol=home" "compress=zstd"];
  };

  fileSystems."/nix" = {
    label = "root";
    fsType = "btrfs";
    options = ["subvol=nix" "compress=zstd" "noatime"];
  };

  fileSystems."/boot" = {
    label = "BOOT";
    fsType = "vfat";
  };

  fileSystems."/glacier/snowscape" = {
    label = "snowscape";
    fsType = "xfs";
  };

  swapDevices = [
    {
      device = "/dev/disk/by-label/swap";
    }
  ];

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  hardware.bluetooth.enable = true;

  services.syncthing = {
    enable = true;
    key = config.age.secrets.fiji-syncthing-key.path;
    cert = config.age.secrets.fiji-syncthing-cert.path;

    settings.paths = {
      # documents = "/glacier/snowscape/documents";
      notes = "/glacier/snowscape/notes";
      # audiobooks = "/glacier/snowscape/audiobooks";
      # books = "/glacier/snowscape/books";
      # comics = "/glacier/snowscape/comics";
      # code = "/glacier/snowscape/code";
    };
  };

  fileSystems."/home/simonwjackson/documents" = {
    device = "/glacier/snowscape/documents";
    options = ["bind"];
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "balanced";

  services.udev.extraRules = ''
    KERNEL=="wlan*", ATTR{address}=="d4:d8:53:90:2b:6c", NAME = "wifi"
  '';

  environment.systemPackages = with pkgs; [
    acpi
  ];

  # services.cuttlefish = {
  #   enable = true;
  #   package = inputs.cuttlefish.packages."x86_64-linux"."cuttlefi.sh";
  #   settings = {
  #     root-dir = "/glacier/snowscape/podcasts";
  #     logs-dir = "/glacier/snowscape/podcasts";
  #     subscriptions = {
  #       "The Morning Stream" = {
  #         url = "https://feeds.acast.com/public/shows/6500eec59654d100127e79b4";
  #       };
  #       "Conan O’Brien Needs A Friend" = {
  #         url = "https://feeds.simplecast.com/dHoohVNH";
  #       };
  #     };
  #   };
  # };

  programs.adb.enable = true;
  users.users.simonwjackson.extraGroups = ["adbusers"];
  services.udev.packages = [
    pkgs.android-udev-rules
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
