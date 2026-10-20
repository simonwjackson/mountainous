# In-place port of the running Home Assistant host at 192.168.1.178.
# Do not add the shared disk layer or use an installer against this host.
{ config, inputs, ... }:
let
  operatorKey = config.mountainous.sshKey;
in
{
  nixos.hosts.rakku = {
    system = "x86_64-linux";
    nixpkgs = inputs.nixpkgs-rakku;
    layers = [
      "server"
      "home-automation"
      "home-network-services"
      "cliproxyapi"
      "tailnet-names"
      "decision-gateway"
    ];
    module =
      { config, lib, ... }:
      {
        imports = [
          (inputs.impermanence-rakku + "/nixos.nix")
          ../../disks/rakku-existing.nix
        ];
        # Cairn's management tools need their own current compilers. Use their
        # self-contained packages without upgrading the home automation runtime.
        sops.package = inputs.sops-nix.packages.x86_64-linux.sops-install-secrets;
        # NeededForUsers decrypts before /etc's persisted file links are set up.
        # This filesystem is mounted in stage 1, so the key exists on cold boot.
        sops.age.sshKeyPaths = lib.mkForce [ "/tundra/permafrost/etc/ssh/ssh_host_ed25519_key" ];
        hjem.cli.package = inputs.hjem.packages.x86_64-linux.hjem;
        mountainous.features.cliproxyapi = {
          enable = true;
          deployPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIGFCc1rafaJq+i2sfHq2RiZdxGMfk/HeNHwKBzGyS7Q cliproxyapi-updater@unzen";
          signingPublicKey = "cliproxyapi-unzen:KgVn63py+E3v950Hko/PdGkqfeSHZjIl0h01bPWac04=";
        };
        # Preserve every driver from the original hardware.nix, including USB
        # storage. The general base layer does not carry usb_storage.
        boot.initrd.availableKernelModules = [
          "ahci"
          "xhci_pci"
          "usb_storage"
          "sd_mod"
        ];
        boot.kernelModules = [
          "igb"
          "cp210x"
          "mt7921u"
        ];
        # Keep the DHCP client and NIC identity that already hold the LAN lease.
        networking.networkmanager.enable = lib.mkForce false;
        networking.useDHCP = true;
        networking.wireless.enable = lib.mkForce false;

        # The old host had no firewall. Preserve home discovery/event callbacks
        # on the existing LAN NIC during the port; do not trust the spare NICs.
        networking.firewall = {
          enable = true;
          trustedInterfaces = [
            "enp1s0"
            "tailscale0"
          ];
        };

        services.zwave-js.serialPort = "/dev/serial/by-id/usb-Silicon_Labs_HubZ_Smart_Home_Controller_61600558-if00-port0";
        services.udev.extraRules = ''
          SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="8a2a", ATTRS{bInterfaceNumber}=="00", SYMLINK+="zwave"
          SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="8a2a", ATTRS{bInterfaceNumber}=="01", SYMLINK+="zigbee"
        '';

        # Preserve UID 1000 and the old home. Cairn's account is added, not a
        # destructive rename. Retire the old login only in a separate change.
        users.users.simon.uid = 1001;
        users.users.simonwjackson = {
          isNormalUser = true;
          uid = 1000;
          home = "/home/simonwjackson";
          extraGroups = [
            "wheel"
            "video"
            "dialout"
          ];
          openssh.authorizedKeys.keys = [ operatorKey ];
          hashedPasswordFile = config.sops.secrets.user-password.path;
        };
        security.sudo.extraRules = [
          {
            users = [ "simonwjackson" ];
            commands = [
              {
                command = "ALL";
                options = [ "NOPASSWD" ];
              }
            ];
          }
        ];

        sops.secrets.zwave-js-secrets = {
          sopsFile = ../../secrets/hosts/rakku.yaml;
          mode = "0400";
        };

        # Namecheap API key. No service reads it yet.
        sops.secrets.namecheap-api-key = {
          sopsFile = ../../secrets/hosts/rakku.yaml;
          mode = "0400";
        };

        assertions = [
          {
            assertion = config.system.stateVersion == "24.11";
            message = "Rakku must retain its existing stateVersion.";
          }
          {
            assertion = config.services.home-assistant.package.version == "2025.12.3";
            message = "Rakku migration must not upgrade Home Assistant.";
          }
          {
            assertion = config.services.zwave-js.package.version == "3.4.0";
            message = "Rakku migration must not upgrade Z-Wave JS.";
          }
          {
            assertion = config.users.users.hass.uid == 286 && config.users.groups.hass.gid == 286;
            message = "Rakku must preserve Home Assistant ownership.";
          }
        ];
      };
  };
}
