{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.mountainous.features.hibernation;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.hibernation = {
    enable = mkEnableOption "Hibernation resume support";

    resumeDevice = mkOption {
      type = types.str;
      default = "";
      example = "/dev/mapper/cryptroot";
      description = ''
        Device to use for hibernation resume.
        For swapfiles, this must be the block device that contains the swapfile.
      '';
    };

    swap = {
      mode = mkOption {
        type = types.enum [
          "partition"
          "swapfile-btrfs"
        ];
        default = "partition";
        description = ''
          Resume source type.
          Use `partition` for a dedicated swap partition and `swapfile-btrfs`
          for a swapfile stored on btrfs.
        '';
      };

      path = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "/swap/swapfile";
        description = ''
          Path to the swapfile when using `swapfile-btrfs` mode.
        '';
      };
    };
  };
}
