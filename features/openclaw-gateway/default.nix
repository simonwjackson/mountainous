{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.openclaw-gateway = {
    enable = mkEnableOption "OpenClaw gateway service";

    user = mkOption {
      type = types.str;
      default = "simonwjackson";
      description = "User to run the gateway as.";
    };

    group = mkOption {
      type = types.str;
      default = "users";
      description = "Group to run the gateway as.";
    };

    port = mkOption {
      type = types.port;
      default = 18789;
      description = "Port the gateway listens on.";
    };

    envFile = mkOption {
      type = types.path;
      description = "EnvironmentFile containing TELEGRAM_BOT_TOKEN, OPENCLAW_GATEWAY_TOKEN, BRAVE_SEARCH_API_KEY, etc.";
    };
  };
}
