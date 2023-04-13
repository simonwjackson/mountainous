{ pkgs, lib, ... }:

let
  wifi = {
    mac = "bc:d0:74:52:86:18";
    name = "wifi";
  };

in
{
  imports = [
    # Include the necessary packages and configuration for Apple Silicon support.
    ../modules/workstation.nix
    ../modules/hidpi.nix
    ../modules/laptop.nix
    ./default.nix
    ./headphones.nix
  ];

  networking.hostName = "ushiro"; # Define your hostname.
  services.flatpak.enable = true;

  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "corne";
      text = ''
        ACTION=="add", SUBSYSTEM=="input", ATTRS{id/product}=="615e", ATTRS{id/vendor}=="1d50", ENV{DISPLAY}=":0", ENV{XAUTHORITY}="/home/simonwjackson/.Xauthority", RUN+="${pkgs.stdenv.shell} -c '${pkgs.xorg.xinput}/bin/xinput float 7'"
        ACTION=="remove", SUBSYSTEM=="input", ATTRS{id/product}=="615e", ATTRS{id/vendor}=="1d50", ENV{DISPLAY}=":0", ENV{XAUTHORITY}="/home/simonwjackson/.Xauthority", RUN+="${pkgs.stdenv.shell} -c '${pkgs.xorg.xinput}/bin/xinput reattach 7 3'"
      '';
      destination = "/etc/udev/rules.d/99-corne.rules";
    })
  ];

  services.udev.extraRules = ''
    KERNEL=="wlan*", ATTR{address}=="${wifi.mac}", NAME = "${wifi.name}"
    KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
  '';

  # List packages installed in system profile. To search, run:
  environment.systemPackages = with pkgs; [
    neovim
    git
    f2fs-tools
    cryptsetup
    fuse3 # for nofail option on mergerfs (fuse defaults to fuse2)
    mergerfs
    mergerfs-tools
    nfs-utils
  ];

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  networking.firewall.enable = false;

  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/d7028fc7-5930-45f4-8fbd-acbecd278703";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/0FA3-0EF8";
      fsType = "vfat";
    };

  swapDevices = [ ];

  networking.interfaces.eth0.useDHCP = lib.mkDefault true;
  networking.interfaces.wifi.useDHCP = lib.mkDefault true;

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

  services.syncthing = {
    overrideDevices = true;
    overrideFolders = true;
    enable = true;
    user = "simonwjackson";
    dataDir = "/tank"; # Default folder for new synced folders
    configDir = "/home/simonwjackson/.config/syncthing";

    devices = {
      ushiro.id = "MIB5GJT-FQWMJ35-EWHDI2O-3IHBOLC-6H5RC6I-I7MEVY7-FQ7MEPO-P3YMCQJ";
      unzen.id = "QKHBVLD-BCDANSP-ED76TFN-JN4U6CF-KOHSUFP-YREMPYV-V7BZG32-BRXV2AV";
      kuro.id = "4YUE3JH-CUR4TTS-RVTNUHZ-2HDENB3-FH3VWIJ-TMCW3X5-JSPKLXB-H2QUEAP";
      haku.id = "XAQBGPZ-5CVMY23-43CAQ5P-QFGGPJS-LCYKSE6-HEFFQM7-XRAIF6E-5XHAWQT";
    };

    extraFlags = [
      "--no-default-folder"
    ];

    extraOptions = {
      ignores = {
        "line" = [
          "**/node_modules"
          "**/build"
          "**/cache"
        ];
      };
    };

    folders = {
      documents.path = "/home/simonwjackson/documents";
      documents.devices = [ "kuro" "unzen" ];

      code.path = "/home/simonwjackson/code";
      code.devices = [ "ushiro" "unzen" ];
    };
  };
}
