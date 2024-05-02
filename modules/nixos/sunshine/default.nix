{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.mountainous.gaming.sunshine;
  # HACK: this iz device (zao) specific
  devices = ["DP-1" "DP-2" "DP-3" "DP-4" "HDMI-1"];
in {
  options.mountainous.gaming.sunshine = {
    enable = lib.mkEnableOption "Sunshine";
  };

  config = lib.mkIf cfg.enable {
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
      ${builtins.concatStringsSep "\n" (map (device: ''
          # Resolutions for ${device}
          # Galaxy Tab 8
          ## 17% (~720p)
          ${pkgs.xorg.xrandr}/bin/xrandr --newmode "1152x721"  145.75  1152 1240 1360 1568  721 724 734 776 -hsync +vsync
          ${pkgs.xorg.xrandr}/bin/xrandr --addmode "${device}" "1152x721"

          ## 25%

          ${pkgs.xorg.xrandr}/bin/xrandr --newmode "1400x876"  215.75  1400 1512 1656 1912  876 879 889 942 -hsync +vsync
          ${pkgs.xorg.xrandr}/bin/xrandr --addmode "${device}" "1400x876"

          ## 38% (~1080p)
          ${pkgs.xorg.xrandr}/bin/xrandr --newmode "1728x1081"  332.00  1728 1872 2056 2384  1081 1084 1094 1161 -hsync +vsync
          ${pkgs.xorg.xrandr}/bin/xrandr --addmode "${device}" "1728x1081"

          ## 42%

          ${pkgs.xorg.xrandr}/bin/xrandr --newmode "1816x1136"  172.25  1816 1936 2128 2440  1136 1139 1149 1178 -hsync +vsync
          ${pkgs.xorg.xrandr}/bin/xrandr --addmode "${device}" "1816x1136"

          ## 50%

          ${pkgs.xorg.xrandr}/bin/xrandr --newmode "1960x1226"  428.00  1960 2128 2336 2712  1226 1229 1239 1316 -hsync +vsync
          ${pkgs.xorg.xrandr}/bin/xrandr --addmode "${device}" "1960x1226"

          # Redmagic 8s Pro

          ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2480x1116"  494.50  2480 2688 2960 3440  1116 1119 1129 1199 -hsync +vsync
          ${pkgs.xorg.xrandr}/bin/xrandr --addmode "${device}" "2480x1116"

          ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2152x968"  370.25  2152 2328 2560 2968  968 971 981 1040 -hsync +vsync
          ${pkgs.xorg.xrandr}/bin/xrandr --addmode "${device}" "2152x968"

          ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2016x907"  323.50  2016 2176 2392 2768  907 910 920 975 -hsync +vsync
          ${pkgs.xorg.xrandr}/bin/xrandr --addmode "${device}" "2016x907"

          ${pkgs.xorg.xrandr}/bin/xrandr --newmode "1760x792"  245.00  1760 1896 2080 2400  792 795 805 852 -hsync +vsync
          ${pkgs.xorg.xrandr}/bin/xrandr --addmode "${device}" "1760x792"

        '')
        devices)}
    '';
  };
}
