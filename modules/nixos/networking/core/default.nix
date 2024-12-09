{
  config,
  lib,
  ...
}: let
  inherit (lib.mountainous) enabled;

  cfg = config.mountainous.networking.core;

  generateUdevRules = interfaces: let
    generateRule = {
      name,
      mac,
    }: ''ATTR{address}=="${mac}", NAME="${name}"'';
  in
    "\n"
    + (builtins.concatStringsSep "\n" (map generateRule interfaces))
    + "\n";
in {
  options.mountainous.networking.core = {
    enable = lib.mkEnableOption "Enable mountainous networking core configuration";

    names = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "The desired name for the interface";
          };
          mac = lib.mkOption {
            type = lib.types.str;
            description = "The MAC address of the interface";
          };
        };
      });
      default = [];
      description = "List of interfaces to rename based on their MAC addresses";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
      "net.ipv6.conf.all.disable_ipv6" = 1;
      "net.ipv6.conf.default.disable_ipv6" = 1;
    };

    networking = {
      useDHCP = lib.mkDefault true;
      domain = "mountaino.us";
      networkmanager.enable = true;
    };

    services = {
      udev.extraRules = generateUdevRules cfg.names;
      resolved = enabled;
    };

    # WARN: This speeds up `nixos-rebuild`, but im not sure if there are any side effects
    systemd.services.NetworkManager-wait-online.enable = false;
  };
}
