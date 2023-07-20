{ lib, ... }:

{
  # options.programs.fuzzy-music = {
  #   enable = lib.mkEnableOption "fuzzy-music";
  # };

  # config = lib.mkIf cfg.enable {
  programs.taskwarrior.config = lib.mkMerge [{
    # uda.linear_id.type = "string";
    # uda.linear_id.label = "Linear ID";
  }];
}
