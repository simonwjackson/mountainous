{
  config,
  lib,
  ...
}: let
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
    enable = lib.mkEnableOption "Enable Mountainous networking core configuration";

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
    services.udev.extraRules = generateUdevRules cfg.names;
    networking = {
      useDHCP = lib.mkDefault true;
      domain = "mountaino.us";
      networkmanager.enable = true;
    };

    # WARN: This speeds up `nixos-rebuild`, but im not sure if there are any side effects
    systemd.services.NetworkManager-wait-online.enable = false;
  };
}
