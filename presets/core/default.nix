{
  lib,
  mountainousPlatform ? "nixos",
  ...
}: {
  imports = lib.optional (mountainousPlatform == "nixos") ./nixos.nix;

  options.mountainous.presets.core = {
    enable = lib.mkEnableOption "core preset";
  };
}
