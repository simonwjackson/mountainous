# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../modules/journal
      ../../modules/syncthing.nix
      ../../modules/sunshine.nix
      ../../modules/gaming.nix
      ../../modules/tailscale.nix
      ../../modules/networking.nix
      ../../profiles/gui
      ../../profiles/audio.nix
      ../../profiles/workstation.nix
      ../../profiles/_common.nix
      ../../users/simonwjackson

  fileSystems."/home/simonwjackson/documents" = {
    device = "/glacier/snowscape/documents";
    options = [ "bind" ];
  };
  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "fiji"; # Define your hostname.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  networking.extraHosts = ''
    100.76.86.139 www.local.hilton.com
  '';

  services.flatpak.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-kde
    ];
  };
  nixpkgs.config.allowUnfree = true;

  # Enable automatic login for the user.
  services.getty.autologinUser = "simonwjackson";

  # Set your time zone.
  time.timeZone = "America/Chicago";

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

  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = "eurosign:e,caps:escape";

  # TODO: Make this a module
  # Printing
  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.avahi.enable = true;
  # Important to resolve .local domains of printers, otherwise you get an error
  # like  "Impossible to connect to XXX.local: Name or service not known"
  services.avahi.nssmdns = true;
  # /Printing

  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  services.syncthing = {
    dataDir = "/home/simonwjackson"; # Default folder for new synced folders

    folders = {                                         
      code.path = "/home/simonwjackson/code";
      documents.path = "/glacier/snowscape/documents";
      gaming-games.path = "/glacier/snowscape/gaming/games";
      gaming-launchers.path = "/glacier/snowscape/gaming/launchers";
      gaming-profiles.path = "/glacier/snowscape/gaming/profiles";
      gaming-systems.path = "/glacier/snowscape/gaming/systems";
      taskwarrior.path = "/home/simonwjackson/.local/share/task";
                                                                                                   
      code.devices = [ "fiji" "unzen" "yari" ];
      documents.devices = [ "fiji" "usu" "unzen" "zao" ];
      gaming-games.devices = [ "fiji" "unzen" "yari" "zao" ];
      gaming-launchers.devices = [ "fiji" "unzen" "zao" ];
      gaming-profiles.devices = [ "fiji" "usu" "unzen" "yari" "zao" ];
      gaming-systems.devices = [ "fiji" "unzen" "zao" ];
      taskwarrior.devices = ["fiji" "unzen" "zao" ];

      gaming-profiles.versioning = {
        type = "staggered";                             
        params = {                                
          cleanInterval = "3600";                                                     
          maxAge = "31536000";                                                                    
        };
      };
    };
  };

  systemd.services.hiltonProxy = {
    description = "Hilton Dev Proxy";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "simonwjackson";
      Environment = "AUTOSSH_GATETIME=0";
      ExecStart = "${pkgs.autossh}/bin/autossh -M 0 -N -o 'ServerAliveInterval 30' -o 'ServerAliveCountMax 3' -D 9999 -L 5400:localhost:5400 sjackson217@ushiro";
    };
  };

  systemd.services.mountSnowscape = {
    script = ''
      install -d -o simonwjackson -g users -m 770 /glacier/snowscape

      ${pkgs.util-linux}/bin/mountpoint -q /glacier/snowscape || ${pkgs.mount}/bin/mount -t bcachefs /dev/disk/by-partuuid/b12cf721-2465-4853-8342-53f2ced215ee:/dev/disk/by-partuuid/ebf24e43-c194-4fd9-aff8-14daa54495c1 /glacier/snowscape
    '';

    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?


  services.xserver.libinput.touchpad.disableWhileTyping = true;
  # services.xserver.libinput.enable = true;
  services.xserver.libinput.tapping = true;
}

