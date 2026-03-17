{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.mountainous.features.openclaw;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.openclaw = {
    enable = mkEnableOption "OpenClaw image generation skills";

    user = mkOption {
      type = types.str;
      default = "simonwjackson";
      description = "User whose ~/.openclaw/skills to manage";
    };

    hfTokenFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to file containing Hugging Face API token (agenix secret)";
    };
  };
}
