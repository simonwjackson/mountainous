{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkDefault;
  inherit (lib.mountainous) enabled;

  cfg = config.mountainous.profiles.base;
in {
  options.mountainous.profiles.base = {
    enable = mkEnableOption "Enable base profile";
  };

  config = lib.mkIf cfg.enable {
    mountainous = {
      impermanence = {
        enable = mkDefault false;
        persistPath = "/tundra/permafrost";
      };
      networking = {
        core = mkDefault enabled;
        tailscale = {
          enable = true;
          interfaceName = "tailscale";
        };
        tailscaled.enable = lib.mkForce false;
      };
      performance = enabled;
    };
  };
}
