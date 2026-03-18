{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.mountainous.presets.server;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.presets.server = {
    enable = mkEnableOption "server preset";

    signingKeyFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Path to a Nix binary-cache signing key. When set, nix.settings.secret-key-files is configured.";
      example = "/etc/nix/signing-key.priv";
    };
  };

  config = mkIf cfg.enable {
    home-manager.users.simonwjackson.imports = [
      ./home.nix
    ];
  };
}
