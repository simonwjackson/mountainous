{
  config,
  pkgs,
  inputs,
  lib,
  modulesPath,
  ...
}: let
  # TODO: This needs to be a configurable module
  enp1s0 = {
    mac = "40:62:31:12:ac:8f";
    name = "lan";
  };
  enp2s0 = {
    mac = "40:62:31:12:ac:90";
    name = "server";
  };
  enp3s0 = {
    mac = "40:62:31:12:ac:91";
    name = "raiden";
  };
  enp4s0 = {
    mac = "40:62:31:12:ac:92";
    name = "wan";
  };
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # INFO: moved from imports
  boot.loader = {
    systemd-boot = {
      enable = true;
      consoleMode = "max";
    };

    efi.canTouchEfiVariables = true;
  };
  # INFO: end

  backpacker.networking.tailscaled.exit-node = true;
  networking.hostName = "rakku"; # Define your hostname.

  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  boot.initrd.availableKernelModules = ["ahci" "xhci_pci" "ehci_pci" "usbhid" "usb_storage" "sd_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/0cac5392-d283-4522-9905-9bd25c0d6a10";
    fsType = "ext4";
  };

  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-uuid/A767-7F22";
    fsType = "vfat";
  };

  swapDevices = [{device = "/dev/disk/by-uuid/7b5f0141-23f7-4e88-a6b1-2fa7f1752443";}];

  time.timeZone = "America/Chicago";

  networking.firewall = {
    enable = lib.mkDefault true;
    allowedTCPPorts = lib.mkAfter [
      # HTTP(S)
      80
      443
      110
    ];
  };

  networking.firewall.trustedInterfaces = lib.mkAfter ["lan" "raiden" "server" "mtn"];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).

  system.stateVersion = "22.05"; # Did you read the comment?
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  services.unifi = {
    enable = true;
    unifiPackage = pkgs.unifi;
    openPorts = true;
  };

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault false;
  networking.interfaces.wan.useDHCP = lib.mkDefault true;
  networking.interfaces.lan.useDHCP = lib.mkDefault false;
  networking.interfaces.server.useDHCP = lib.mkDefault false;
  networking.interfaces.raiden.useDHCP = lib.mkDefault false;

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="${enp1s0.mac}", NAME = "${enp1s0.name}"
    ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="${enp2s0.mac}", NAME = "${enp2s0.name}"
    ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="${enp3s0.mac}", NAME = "${enp3s0.name}"
    ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="${enp4s0.mac}", NAME = "${enp4s0.name}"
  '';

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  services.dnsmasq = {
    enable = true;
    extraConfig = ''
      domain-needed
      bogus-priv
      no-resolv
      local=/lan/
      # listen-address=::1,127.0.0.1,192.18.1.1
      # expand-hosts
      except-interface=wan
      # dhcp-option=option:router,192.18.1.1
      dhcp-authoritative
      # dhcp-leasefile=/var/lib/dnsmasq/dnsmasq.leases

      dhcp-range=192.18.1.1,192.18.1.254,255.255.255.0,4h

      #expand-hosts
      #domain=lan

      # Cloudflare
      server=1.1.1.1
      server=1.0.0.1
      #server=2606:4700:4700::1111
      #server=2606:4700:4700::1001

      # Google
      server=8.8.8.8
      server=8.8.4.4

      # OpenDNS
      server=208.67.220.220
      server=208.67.222.220
      server=208.67.220.222
      #server=2620:119:35::35
      #server=2620:119:53::53

    '';
  };

  networking.nat.enable = true;
  networking.nat.internalInterfaces = ["lan" "mtn"];
  networking.nat.externalInterface = "wan";

  networking.interfaces.lan.ipv4.addresses = [
    {
      address = "192.18.1.1";
      prefixLength = 24;
    }
  ];
}
