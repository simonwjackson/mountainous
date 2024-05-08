{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.mountainous.gaming.sunshine;

  # HACK: this iz device (zao) specific
  ports = [
    "DP-1"
    "DP-1-0"
    "DP-1-1"
    "DP-1-2"
    "DP-1-3"
    "DP-1-4"
    "DP-1-5"
    "DP-1-6"
    "DP-1-7"
    "DP-2"
    "DP-2-1"
    "DP-2-2"
    "DP-2-3"
    "DP-3"
    "DP-4"
    "HDMI-1"
  ];
in {
  options.mountainous.gaming.sunshine = {
    enable = mkEnableOption "Whether to enable Sunshine";
  };

  config = mkIf cfg.enable {
    services.udev.extraRules = ''
      KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
      KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess"
    '';

    environment.systemPackages = [
      pkgs.sunshine
    ];

    security.wrappers.sunshine = {
      owner = "root";
      group = "root";
      capabilities = "cap_sys_admin+p";
      source = "${pkgs.sunshine}/bin/sunshine";
    };

    systemd.user.services.sunshine = {
      description = "sunshine";
      wantedBy = ["graphical-session.target"];
      serviceConfig = {
        ExecStart = "${config.security.wrapperDir}/sunshine";
        Restart = "always";
      };
    };

    services.xserver.displayManager.setupCommands = ''
      ${pkgs.xorg.xrandr}/bin/xrandr --newmode "1280x720_120"  162.00  1280 1376 1512 1744  720 723 728 775 -hsync +vsync

      ${builtins.concatStringsSep "\n" (map (port: ''
          # Resolutions for ${port}

          ${pkgs.xorg.xrandr}/bin/xrandr --addmode "${port}" 1280x720_120"
        '')
        ports)}
    '';
  };
}
