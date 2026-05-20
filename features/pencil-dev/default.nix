{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) literalExpression mkEnableOption mkIf mkOption types;
  cfg = config.mountainous.features.pencil-dev;
in {
  options.mountainous.features.pencil-dev = {
    enable = mkEnableOption "Pencil desktop app and CLI";

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ./package.nix {};
      defaultText = literalExpression "pkgs.callPackage ./package.nix {}";
      description = "Pencil desktop package to install via Home Manager.";
    };

    cliPackage = mkOption {
      type = types.package;
      default = pkgs.callPackage ./package-cli.nix {};
      defaultText = literalExpression "pkgs.callPackage ./package-cli.nix {}";
      description = "Pencil CLI package to install via Home Manager.";
    };
  };

  config = mkIf cfg.enable {
    home-manager.users.simonwjackson.imports = [
      ./home.nix
    ];
  };
}
