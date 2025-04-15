{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.mountainous.performance;
in {
  options.mountainous.performance = {
    enable = lib.mkEnableOption "Enable performance tuning";
  };

  config = lib.mkIf cfg.enable {
    # Zram swap is a compressed RAM disk that can be used as a swap space
    zramSwap.enable = true;
  };
}
