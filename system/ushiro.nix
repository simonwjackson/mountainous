# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ modulesPath, stdenv, config, pkgs, lib, ... }:

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
    ./apple-silicon-support
    ./default.nix
    ./headphones.nix
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.efi.canTouchEfiVariables = false;

  networking.hostName = "ushiro"; # Define your hostname.

  hardware.bluetooth.enable = true;
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

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.

  boot.initrd.availableKernelModules = [ "usb_storage" "sdhci_pci" ];
  boot.initrd.kernelModules = [ ];
  # boot.kernelModules = [ ];
  # boot.kernelPatches = [{
  #   name = "f2fs";
  #   patch = null;
  #   extraConfig = ''
  #     CONFIG_F2FS_FS y
  #     CONFIG_F2FS_STAT_FS y
  #     CONFIG_F2FS_FS_XATTR y
  #     CONFIG_F2FS_FS_POSIX_ACL y
  #     CONFIG_F2FS_FS_SECURITY y
  #     CONFIG_F2FS_CHECK_FS y
  #     CONFIG_F2FS_FS_ENCRYPTION y
  #     CONFIG_F2FS_FAULT_INJECTION y
  #   '';
  # }];
  boot.kernelParams = [
    "apple_dcp.show_notch=1"
  ];
  boot.extraModulePackages = [ ];
  boot.extraModprobeConfig = ''
    options hid_apple iso_layout=0
  '';

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

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.eth0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp1s0f0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
  # high-resolution display
  # hardware.video.hidpi.enable = lib.mkDefault true;
  hardware.asahi.addEdgeKernelConfig = true;

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
