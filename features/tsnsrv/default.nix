{
  lib,
  pkgs,
  tsnsrv,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.tsnsrv = {
    enable = mkEnableOption "tsnsrv Tailscale reverse-proxy services";

    package = mkOption {
      type = types.package;
      default = tsnsrv.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalExpression "tsnsrv.packages.\${system}.default";
      description = "The tsnsrv package to use.";
    };

    authKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Default Tailscale auth-key file for all services.";
    };

    services = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          backendUrl = mkOption {
            type = types.str;
            description = "Backend URL to proxy (e.g. http://127.0.0.1:8080).";
          };

          authKeyFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Per-service Tailscale auth-key file (overrides the global default).";
          };
        };
      });
      default = {};
      description = "Attrset of tsnsrv proxy services to create.";
    };
  };
}
