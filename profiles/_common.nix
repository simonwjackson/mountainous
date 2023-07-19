{ pkgs, lib, ... }:

let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz";
in
{
  imports = [
    (import "${home-manager}/nixos")
    ../modules/git.nix
    ../modules/main-user.nix
    ../modules/tailscale.nix
    ../modules/zsh
    ../modules/neovim
    ../modules/terminal
    ../modules/tmux-all-sessions
    ../modules/tmux-all-servers
  ];

  # WARN: This speeds up `nixos-rebuild`, but im not sure if there are any side effects
  systemd.services.NetworkManager-wait-online.enable = false;

  home-manager.users.simonwjackson = { config, pkgs, ... }: {
    # Custom Scripts
    programs.tmux-all-sessions.enable = true;
    programs.tmux-all-servers.enable = true;
  };

  networking.firewall.allowPing = true;
  networking.firewall.enable = false;
  networking.networkmanager.enable = true;
  networking.useDHCP = lib.mkDefault true;
  nixpkgs.config.allowUnfree = true;
  programs.mosh.enable = true;
  security.sudo.wheelNeedsPassword = false;
  services.automatic-timezoned.enable = true;
  services.gpm.enable = true; # TTY mouse
  system.copySystemConfiguration = true;
  users.defaultUserShell = pkgs.zsh;

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '';
  };

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  console = {
    font = lib.mkDefault "Lat2-Terminus16";
    keyMap = "us";
  };

  environment.systemPackages = with pkgs; [
    neovim
    git
    tmux
    wget
    git
    w3m
    ripgrep
    tmux
    lf
    _1password
  ];

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    passwordAuthentication = false;
    permitRootLogin = "no";
    extraConfig = ''
      #PubkeyAcceptedKeyTypes ssh-rsa
    '';
  };

  services.udev.packages = [
    pkgs.android-udev-rules
  ];

  services.dbus.packages = [
    (pkgs.writeTextFile {
      name = "dbus-monitor-policy";
      text = ''
        <!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
          "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
        <busconfig>
          <policy user="simonwjackson">
            <allow send_destination="org.freedesktop.DBus" send_interface="org.freedesktop.DBus.Monitoring" />
            <allow send_type="method_call" send_interface="org.freedesktop.DBus.Monitoring"/>
            <allow send_type="signal" send_interface="org.freedesktop.DBus.Properties" send_member="PropertiesChanged" send_path="/org/bluez"/>
          </policy>
        </busconfig>
      '';
      destination = "/etc/dbus-1/system.d/dbus-monitor-policy.conf";
    })
  ];

  services.autofs.enable = true;
  services.autofs.autoMaster = ''
    /net -hosts --timeout=60
  '';

}
