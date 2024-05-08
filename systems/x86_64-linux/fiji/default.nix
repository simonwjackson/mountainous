{
  config,
  inputs,
  lib,
  modulesPath,
  options,
  pkgs,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  age.secrets.game-collection-sync.file = ../../../secrets/game-collection-sync.age;
  age.secrets.fiji-syncthing-key.file = ../../../secrets/fiji-syncthing-key.age;
  age.secrets.fiji-syncthing-cert.file = ../../../secrets/fiji-syncthing-cert.age;

  age = {
    identityPaths =
      options.age.identityPaths.default
      ++ [
        # TODO: Pull this value from somewhere else in the config
        "/home/simonwjackson/.ssh/agenix"
      ];
  };

  mountainous = {
    battery.enable = true;
    performance.enable = true;
    profiles.laptop.enable = true;
    boot.quiet = false;
    networking.core.names = [
      {
        name = "wifi";
        mac = "d4:d8:53:90:2b:6c";
      }
    ];
  };

  # START: From old modules
  console = {
    useXkbConfig = true;
    earlySetup = false;
  };

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

  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;

    extraPortals = with pkgs; [
      xdg-desktop-portal-kde
    ];
  };

  boot.supportedFilesystems = ["xfs"];
  networking.hostName = "fiji";

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.availableKernelModules = ["xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];

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

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  system.stateVersion = "23.05"; # Did you read the comment?
}
