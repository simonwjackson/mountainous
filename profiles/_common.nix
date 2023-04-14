{ pkgs, lib, ... }:

{
  imports = [
    ../modules/tailscale.nix
  ];

  networking.firewall.allowPing = true;
  networking.firewall.enable = false;
  networking.networkmanager.enable = true;
  networking.useDHCP = lib.mkDefault true;
  nixpkgs.config.allowUnfree = true;
  programs.mosh.enable = true;
  programs.zsh.enable = true;
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

  services.flatpak.enable = true;
  xdg.portal = {
    enable = true;
  };
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
}
