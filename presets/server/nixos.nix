{
  config,
  lib,
  ...
}: let
  inherit (lib) mkDefault mkIf;
  cfg = config.mountainous.presets.server;
in {
  config = mkIf cfg.enable {
    mountainous.tailscale.extraSetFlags = mkDefault ["--netfilter-mode=nodivert"];
  };
}
