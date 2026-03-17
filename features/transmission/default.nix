{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.mountainous.features.transmission;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.transmission = {
    enable = mkEnableOption "Transmission with Mountainous defaults";

    user = mkOption {
      type = types.str;
      default = "transmission";
      description = "User account under which Transmission runs.";
    };

    group = mkOption {
      type = types.str;
      default = "media";
      description = "Primary group for Transmission; usually the shared media group.";
    };

    port = mkOption {
      type = types.port;
      default = 9091;
      description = "Transmission RPC and web UI port.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the Transmission RPC port in the firewall.";
    };

    settings = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional settings forwarded to services.transmission.settings.";
      example = {
        "download-dir" = "/srv/storage/downloads/torrents/completed";
        "watch-dir-enabled" = true;
      };
    };
  };
}
