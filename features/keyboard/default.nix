{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.mountainous.features.keyboard;
  defaultKanataConfig = ''
    (defcfg
      process-unmapped-keys yes
      concurrent-tap-hold yes
      linux-continue-if-no-devs-found yes
    )

    (defsrc
      a s h j k l u i o m comm . left down up right esc ret spc
    )

    (defalias
      a-arr (tap-hold 200 200 a (layer-while-held arrows))
      s-pad (tap-hold 200 200 s (layer-while-held numpad))
      spc-met (tap-hold 200 200 spc lmet)
    )

    (defchordsv2
      (j k) (macro ret) 150 first-release (arrows)
      (k l) (macro esc) 150 first-release (arrows)
    )

    (deflayer base
      @a-arr @s-pad h j k l u i o m comm . XX XX XX XX XX XX @spc-met
    )

    (deflayer arrows
      a s left down up right u i o m comm . XX XX XX XX XX XX @spc-met
    )

    (deflayer numpad
      a s h kp4 kp5 kp6 kp7 kp8 kp9 kp1 kp2 kp3 XX XX XX XX XX XX kp0
    )
  '';
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.keyboard = {
    enable = mkEnableOption "keyboard remapping";

    package = mkOption {
      type = types.package;
      default = pkgs.kanata;
      description = "Kanata package to use for the remapper service and CLI.";
    };

    config = mkOption {
      type = types.lines;
      default = defaultKanataConfig;
      description = "Keyboard remapping configuration.";
    };
  };
}
