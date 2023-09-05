# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).

{ lib, config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../modules/syncthing.nix
      # ../../modules/terminal
      # ../../modules/neovim
      ../../modules/timezone.nix
      ../../modules/sunshine.nix
      ../../modules/tailscale.nix
    ];


  fileSystems = {
    "/home/simonwjackson/.local/share/dolphin-emu/GC" = {
      device = "/storage/gaming/profiles/simonwjackson/progress/saves/nintendo-gamecube/";
      options = [ "bind" ];
    };

    "/home/simonwjackson/.local/share/dolphin-emu/Wii/title" = {
      device = "/storage/gaming/profiles/simonwjackson/progress/saves/nintendo-wii/";
      options = [ "bind" ];
    };

    "/home/simonwjackson/.local/share/Cemu/mlc01/usr" = {
      device = "/storage/gaming/profiles/simonwjackson/progress/saves/nintendo-wiiu/";
      options = [ "bind" ];
    };

    "/home/simonwjackson/.local/share/yuzu/sdmc" = {
      device = "/glacier/snowscape/gaming/profiles/simonwjackson/progress/saves/nintendo-switch/sdmc";
      options = [ "bind" ];
    };

    "/home/simonwjackson/.local/share/yuzu/shader" = {
      device = "/glacier/snowscape/gaming/emulators/yuzu/shader";
      options = [ "bind" ];
    };

    "/home/simonwjackson/.local/share/yuzu/keys" = {
      device = "/glacier/snowscape/gaming/systems/nintendo-switch/keys";
      options = [ "bind" ];
    };

    "/home/simonwjackson/.local/share/yuzu/nand" = {
      device = "/glacier/snowscape/gaming/gaming/profiles/simonwjackson/progress/saves/nintendo-switch/nand";
      options = [ "bind" ];
    };
  };

  systemd.services.mountSteamAppsOverlay = {
    after = [ "mountTank.service" ];
    script = ''
      ${pkgs.util-linux}/bin/mountpoint -q /home/simonwjackson/.var/app/com.valvesoftware.Steam/data/Steam/steamapps || ${pkgs.mount}/bin/mount --bind /glacier/snowscape/gaming/games/steam/steamapps /home/simonwjackson/.var/app/com.valvesoftware.Steam/data/Steam/steamapps
    '';
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
    };
  };

  services.flatpak.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-kde
    ];
  };
  

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # nix.settings.substituters = [ "https://aseipp-nix-cache.global.ssl.fastly.net" ];
  nixpkgs.config.allowUnfree = true;
  networking.hostName = "zao"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

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


  # Enable the Plasma 5 Desktop Environment.
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.desktopManager.plasma5.enable = true;
  services.xserver.displayManager.autoLogin.enable = true;
  services.xserver.displayManager.autoLogin.user = "simonwjackson";
  

  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  sound.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [
      firefox
      git
      tmux
      neovim
      yuzu
      cemu
      retroarchFull
      kitty
      sunshine
    ];
  };

  programs.steam.enable = true;

  security.sudo.wheelNeedsPassword = false;

  services.syncthing = {
    dataDir = "/home/simonwjackson"; # Default folder for new synced folders

    folders = {
      gaming.path = "/storage/gaming";
      gaming.devices = [ "unzen" ];
    };
  };

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

}

