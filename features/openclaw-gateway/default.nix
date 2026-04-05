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

    matrix = {
      enable = mkEnableOption "Matrix channel for OpenClaw";

      homeserver = mkOption {
        type = types.str;
        example = "https://matrix.hummingbird-lake.ts.net";
        description = "Matrix homeserver URL reachable from the gateway host.";
      };

      userId = mkOption {
        type = types.str;
        example = "@openclaw:yari";
        description = "Full Matrix user ID for the bot (e.g., @openclaw:yari).";
      };

      passwordFile = mkOption {
        type = types.path;
        description = "Path to a file containing the Matrix bot password.";
      };

      dmPolicy = mkOption {
        type = types.enum ["pairing" "allowlist" "open" "disabled"];
        default = "open";
        description = ''
          DM access control policy.
          - pairing: unknown senders get a pairing code
          - allowlist: only listed users can DM
          - open: anyone can DM (requires allowFrom = ["*"])
          - disabled: no DMs
        '';
      };

      allowFrom = mkOption {
        type = types.listOf types.str;
        default = ["*"];
        description = ''
          Matrix user IDs allowed to DM the bot.
          Use ["*"] with dmPolicy = "open" to allow everyone.
        '';
      };

      groupPolicy = mkOption {
        type = types.enum ["allowlist" "open" "disabled"];
        default = "allowlist";
        description = "Room/group access policy.";
      };
    };
  };
}
