# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).

{ lib, config, pkgs, ... }:

{
  imports = [
  # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../modules/syncthing.nix
      ../../modules/tailscale.nix
      ../../modules/gaming-host.nix
      # ../../modules/terminal
      # ../../modules/neovim
      ../../modules/timezone.nix
      ../../modules/sunshine.nix
      ../../modules/tailscale.nix
    ];

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
      kitty
    ];
  };

  security.sudo.wheelNeedsPassword = false;

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

# services.create_ap = {
#   enable = false;
#   settings = {
#     FREQ_BAND = 5;
#     HT_CAPAB = "[HT20][HT40-][HT40+][SHORT-GI-20][SHORT-GI-40][TX-STBC][MAX-AMSDU-7935][DSSS_CCK-40][PSMP]";
#     VHT_CAPAB = "[MAX-MPDU-11454][RXLDPC][SHORT-GI-80][TX-STBC-2BY1][RX-STBC-1][MAX-A-MPDU-LEN-EXP0]";
#     IEEE80211AC = true;
#     IEEE80211N = true;
#     GATEWAY = "192.18.5.1";
#     PASSPHRASE = "asdfasdfasdf";
#     INTERNET_IFACE = "wlp0s20f0u3";
#     WIFI_IFACE = "wlp0s20f3";
#     SSID = "hopstop";
#   };
# };

# networking.wlanInterfaces = {
#   "wlan-station0" = { device = "wlp0s2";};
#   "wlan-ap0"      = { device = "wlp0s2"; mac = "08:11:96:0e:08:0a"; };
# };
# 
# networking.networkmanager.unmanaged = [ "interface-name:wlp*" ]
#     ++ lib.optional config.services.hostapd.enable "interface-name:${config.services.hostapd.interface}";
# 
# services.hostapd = {
#   enable        = true;
#   interface     = "wlan-ap0";
#   hwMode        = "g";
#   ssid          = "nix";
#   wpaPassphrase = "mysekret";
# };
# 
# services.haveged.enable = config.services.hostapd.enable;
# 
# networking.interfaces."wlan-ap0".ipv4.addresses =
#   lib.optionals config.services.hostapd.enable [{ address = "192.168.12.1"; prefixLength = 24; }];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
  
  programs.mosh.enable = true;

  services.syncthing = {
    dataDir = "/home/simonwjackson"; # Default folder for new synced folders

    folders = {
      documents.path = "/glacier/snowscape/documents";
      gaming-profiles.path = "/glacier/snowscape/gaming/profiles";
      gaming-games.path = "/glacier/snowscape/gaming/games";
      taskwarrior.path = "/home/simonwjackson/.local/share/task";
      # code.path = "/home/simonwjackson/code";

      documents.devices = [ "fiji" "unzen" "zao" "yari" "haku" ];
      gaming-profiles.devices = [ "fiji" "unzen" "zao" "yari" "haku" ];
      gaming-games.devices = [ 
        "zao"
        # "fiji" "unzen" "zao" "yari" "haku"
      ];
      taskwarrior.devices = [ "fiji" "unzen" "zao" ];
      # code.devices = [ "fiji" "kita" "unzen" "yari" ];

      # gaming-profiles.versioning = 

      gaming-profiles.versioning = {
        type = "staggered";
        params = {
          cleanInterval = "3600";
          maxAge = "31536000";
        };
      };
    };
  };
}
