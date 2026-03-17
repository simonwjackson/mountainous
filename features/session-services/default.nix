{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption types;

  sessionServiceType = types.submodule ({name, ...}: {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to manage this session service.";
      };

      command = mkOption {
        type = types.str;
        description = "Command used to start the service.";
      };

      environment = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Environment variables exported before starting the service.";
      };

      validateCommand = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional command used to validate the running service instance.";
      };

      startup = mkOption {
        type = types.enum [
          "ensure-running"
          "once"
          "always-restart"
        ];
        default = "ensure-running";
        description = "Startup behavior when a shell session initializes this service.";
      };

      stateDir = mkOption {
        type = types.str;
        default = "${config.user.home}/.local/state/session-services/${name}";
        description = "State directory used to store locks and runtime metadata for the service.";
      };
    };
  });
in {
  options.mountainous.sessionServices = mkOption {
    type = types.attrsOf sessionServiceType;
    default = {};
    description = "Session-managed services started and monitored from interactive shell sessions.";
  };
}
