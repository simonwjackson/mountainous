{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.mountainous.features.evdev-hotkey;
in {
  config = mkIf cfg.enable {
    # Grant the primary user access to /dev/input/event* devices.
    users.users.simonwjackson.extraGroups = ["input"];

    home-manager.users.simonwjackson.imports = [
      ./home.nix
    ];
  };
}
