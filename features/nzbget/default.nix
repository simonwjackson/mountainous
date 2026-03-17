{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.mountainous.features.nzbget;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.nzbget = {
    enable = mkEnableOption "NZBGet with shared media defaults";

    user = mkOption {
      type = types.str;
      default = "nzbget";
      description = "User account under which NZBGet runs.";
    };

    group = mkOption {
      type = types.str;
      default = "media";
      description = "Primary group for NZBGet; usually the shared media group.";
    };

    listenAddress = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Bind address for the NZBGet UI and RPC interface.";
    };

    port = mkOption {
      type = types.port;
      default = 6789;
      description = "NZBGet control port.";
    };

    controlUsername = mkOption {
      type = types.str;
      default = "nzbget";
      description = "Username for the NZBGet web UI and RPC interface.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the NZBGet port in the firewall.";
    };

    settings = mkOption {
      type = types.attrsOf (types.oneOf [types.bool types.int types.str]);
      default = {};
      description = "Non-secret NZBGet settings forwarded to services.nzbget.settings.";
      example = {
        "Server1.Name" = "primary";
        "Server1.Host" = "news.example.com";
        "Server1.Port" = 563;
        "Server1.Encryption" = true;
        "Server1.Connections" = 20;
        "Server1.Username" = "my-user";
      };
    };

    secretSettings = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = ''
        Secret-backed NZBGet settings, mapping config key to a runtime file path.

        These values are patched into the config file during service startup so they
        do not end up in the Nix store.
      '';
      example = {
        ControlPassword = "/run/agenix/nzbget-control-password";
        "Server1.Password" = "/run/agenix/usenet-primary-password";
      };
    };
  };
}
