{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.mountainous.transmission;
in {
  options.mountainous.transmission = {
    enable = mkEnableOption "Transmission BitTorrent client";

    settings = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional settings to pass to services.transmission.settings";
      example = {
        download-dir = "/media/downloads";
        speed-limit-up = 100;
      };
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open firewall ports for transmission";
    };
  };

  config = mkIf cfg.enable {
    services.transmission = {
      enable = true;
      package = pkgs.transmission_4;
      openFirewall = cfg.openFirewall;
      settings =
        {
          rpc-bind-address = "0.0.0.0";
          rpc-whitelist-enabled = false;
          rpc-host-whitelist-enabled = false;
        }
        // cfg.settings;
    };
  };
}
