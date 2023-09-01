{ config, lib, pkgs, modulesPath, ... }: {
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
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${config.security.wrapperDir}/sunshine";
    };
  };

  services.xserver.displayManager.setupCommands = ''
    # Note 9
      
    ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2960x1440_60.00"  361.00  2960 3176 3496 4032  1440 1443 1453 1493 -hsync +vsync
    ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2960x1440_60.00"
      
    ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2960x1440_30.00"  169.00  2960 3096 3400 3840  1440 1443 1453 1468 -hsync +vsync
    ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2960x1440_30.00"

    ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2224x1080_60.00"  199.75  2224 2368 2600 2976  1080 1083 1093 1120 -hsync +vsync
    ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2224x1080_60.00"    

    ${pkgs.xorg.xrandr}/bin/xrandr --newmode "1480x720_60.00"   86.25  1480 1552 1704 1928  720 723 733 748 -hsync +vsync
    ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "1480x720_60.00"

    # Z Fold 4
    ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2176x1812_120.00"  708.75  2176 2368 2608 3040  1812 1815 1825 1944 -hsync +vsync
    ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2176x1812_120.00"

    ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2176x1812_60.00"  336.75  2176 2352 2584 2992  1812 1815 1825 1877 -hsync +vsync
    ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2176x1812_60.00"

    ${pkgs.xorg.xrandr}/bin/xrandr --newmode "1296x1080_120.00"  249.25  1296 1408 1544 1792  1080 1083 1093 1160 -hsync +vsync
    ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "1296x1080_120.00"

    # Pixel 3
    ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2160x1080_60.00"  194.50  2160 2304 2528 2896  1080 1083 1093 1120 -hsync +vsync
    ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2160x1080_60.00"

    ## 0.5x
    ${pkgs.xorg.xrandr}/bin/xrandr --newmode "1080x540_60.00"   46.00  1080 1120 1224 1368  540 543 553 562 -hsync +vsync
    ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "1080x540_60.00"
  '';
}
