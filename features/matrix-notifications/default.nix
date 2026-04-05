{
  config,
  lib,
  ...
}: let
  inherit (lib) mkDefault mkEnableOption mkIf mkOption types;
  cfg = config.mountainous.features.matrix-notifications;
in {
  options.mountainous.features.matrix-notifications = {
    enable = mkEnableOption "Matrix desktop notification daemon with dismiss sync";

    homeserverUrl = mkOption {
      type = types.str;
      default = "https://matrix.hummingbird-lake.ts.net";
      description = "Matrix homeserver URL (e.g., https://matrix.example.ts.net).";
    };

    userId = mkOption {
      type = types.str;
      default = "@simonwjackson:yari";
      description = "Matrix user ID for the notification daemon (e.g., @user:server).";
    };

    accessTokenFile = mkOption {
      type = types.path;
      default = config.age.secrets.matrix-access-token.path;
      description = "Path to a file containing the Matrix access token (agenix secret).";
    };

    rooms = mkOption {
      type = types.listOf types.str;
      default = ["#notifications:yari"];
      description = ''
        Matrix room IDs or aliases to monitor for notifications.
        Supports both room IDs (!abc123:server) and aliases (#room:server).
        The daemon only creates desktop notifications for messages in these rooms.
      '';
    };
  };

  config = mkIf cfg.enable {
    age.secrets.matrix-access-token = {
      owner = mkDefault "simonwjackson";
      mode = mkDefault "0400";
    };

    home-manager.users.simonwjackson.imports = [
      ./home.nix
    ];
  };
}
