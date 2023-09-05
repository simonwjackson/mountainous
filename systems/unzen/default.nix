# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).

{ config, pkgs, ... }:

# let
#   unstable = import <nixos-unstable> { config = { allowUnfree = true; }; };
# in 
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../modules/tailscale.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable the Plasma 5 Desktop Environment.
  services.xserver.desktopManager.plasma5.enable = true;

  services.xserver.displayManager = {
    sddm.enable = true;
    autoLogin.enable = true;
    autoLogin.user = "simonwjackson";
  };

  networking.hostName = "unzen"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.
  

  # Set your time zone.
  # time.timeZone = "Europe/Amsterdam";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkbOptions in tty.
  # };

  # Enable the X11 windowing system.
  services.xserver.enable = true;


  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.simonwjackson = {
    initialPassword = "asdfasdfasdf";
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [
      mpv
      neovim
      tmux
      kitty
      git
      firefox
      btop

      yuzu
      cemu
      retroarchFull
      sunshine
      dolphinEmu
    ];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  # environment.systemPackages = with pkgs; [
  #   vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #   wget
  # ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  system.copySystemConfiguration = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

  services.flatpak.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-kde
    ];
  };

  hardware.bluetooth.enable = true;

  services.udev.extraRules = ''
    KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
    KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess"
  '';

  environment.systemPackages = [
    pkgs.sunshine
  ];

  security.wrappers.sunshine = {
    owner = "root";
    group = "root";
    capabilities = "cap_sys_admin+p";
    source = "${pkgs.sunshine}/bin/sunshine";
  };

  systemd.user.services.sunshine = {
    description = "sunshine";
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${config.security.wrapperDir}/sunshine";
    };
  };

  services.zerotierone.enable = true;
  services.zerotierone.joinNetworks = [ "abfd31bd47735e14" ]; # ZT NETWORK ID

  services.autofs.enable = true;
  services.autofs.autoMaster = ''
    /net -hosts --timeout=60
  '';

  systemd.services.ensureNfsRoot = {
    script = ''
      install -d -o nobody -g nogroup -m 770 /export
    '';
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
    };
  };

  fileSystems."/export/snowscape" = {
    device = "/glacier/snowscape";
    options = [ "bind" ];
  };

  fileSystems."/home/simonwjackson/code" = {
    device = "/glacier/snowscape/code";
    options = [ "bind" ];
  };

  services.nfs.server = {
    enable = true;
    exports = ''
      /export		192.18.0.0/16(rw,fsid=0,no_subtree_check,crossmnt)	100.0.0.0/8(rw,fsid=0,no_subtree_check,crossmnt)
      /export/snowscape	192.18.0.0/16(fsid=1,insecure,rw,sync,no_subtree_check)	100.0.0.0/8(fsid=1,insecure,rw,sync,no_subtree_check)
    '';
  };

  services.samba-wsdd.enable = true; # make shares visible for windows 10 clients
  services.samba = {
    enable = true;
    securityType = "user";
    extraConfig = ''
      workgroup = WORKGROUP
      server string = smbnix
      netbios name = smbnix
      security = user
      #use sendfile = yes
      #max protocol = smb2
      # note: localhost is the ipv6 localhost ::1
      hosts allow = 100. 192.18. 127.0.0.1 localhost
      hosts deny = 0.0.0.0/0
      guest account = nobody
      map to guest = bad user
      acl allow execute always = True
    '';
    shares = {
      snowscape = {
        path = "/glacier/snowscape";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "simonwjackson";
        "force group" = "users";
      };
    };
  };

  systemd.user.services.startSteam = {
    path = with pkgs; [ flatpak ];
    description = "Start Steam Flatpak app";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "mountSteamAppsOverlay.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.flatpak}/bin/flatpak run com.valvesoftware.Steam";
      Restart = "on-failure";
    };
  };

  services.borgbackup.jobs = {
    gaming-profiles = {
      paths = "lacier/snowscape/gaming/profiles";
      repo = "/glacier/iceberg/permafrost/gaming/profiles";
      encryption.mode = "none";
      compression = "zstd,22";
      startAt = "daily"; # every day
      exclude = [ ];
    };

    photos = {
      paths = "/glacier/snowscape/photos";
      repo = "/glacier/iceberg/permafrost/photos";
      encryption.mode = "none";
      compression = "zstd,22";
      startAt = "daily"; # every day
      exclude = [ ];
    };

    notes = {
      paths = "/glacier/snowscape/documents/notes";
      repo = "/glacier/iceberg/permafrost/notes";
      encryption.mode = "none";
      startAt = "daily"; # every day
      exclude = [ ];
    };
  };

  services.syncthing = {
    enable = true;
    overrideDevices = true;
    overrideFolders = true;
    user = "simonwjackson";
    configDir = "/home/simonwjackson/.config/syncthing";

    devices = {
      fiji.id = "MW4FWKE-NPIP5BP-LAB7Y75-5JOVKKO-PBVZPIF-DMPGRP3-3GUSVII-SMWDFQY";
      unzen.id = "ETEYYE4-C3P2L34-HIV54WA-XQRERGB-LXL5ZRZ-FVA4EXR-YUDRQVL-HV2FDQA";
      zao.id = "CTOOG4Z-5WK7MDW-UQ3KHOI-YEMDGQF-D6JSIMG-BNPJZWN-MPN3RTO-TBFKRAN";
    };

    extraFlags = [
      "--no-default-folder"
      "--gui-address=0.0.0.0:8384"
    ];

    extraOptions = {
      gui = {
        user = "simonwjackson";
        password = "asdfasdfasdf";
      };

      ignores = {
        "line" = [
          "**/node_modules"
          "**/build"
          "**/cache"
        ];
      };
    };

    folders = {
      documents.path = "/glacier/snowscape/documents";
      gaming-profiles.path = "/glacier/snowscape/gaming/profiles";
      taskwarrior.path = "/home/simonwjackson/.local/share/task";
      code.path = "/home/simonwjackson/code";

      documents.devices = [ "fiji" "unzen" "zao" ];
      gaming-profiles.devices = [ "fiji" "unzen" "zao" ];
      taskwarrior.devices = [ "fiji" "unzen" "zao" ];
      code.devices = [ "fiji" "unzen" "zao" ];

      gaming-profiles.versioning = {
        type = "staggered";
        params = {
          cleanInterval = "3600";
          maxAge = "31536000";
        };
      };
    };
  };

  programs.mosh.enable = true;
}
