{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.presets.workstation = {
    enable = mkEnableOption "workstation preset";
  };
}
