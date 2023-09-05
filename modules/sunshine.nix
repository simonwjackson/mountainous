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

    ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2216x1078_60.00"  199.00  2216 2360 2592 2968  1078 1081 1091 1118 -hsync +vsync
    ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2216x1078_60.00" 

    ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2096x1020_60.00"  177.50  2096 2232 2448 2800  1020 1023 1033 1058 -hsync +vsync
    ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2096x1020_60.00"

    ${pkgs.xorg.xrandr}/bin/xrandr --newmode "1480x720_60.00"   86.25  1480 1552 1704 1928  720 723 733 748 -hsync +vsync
    ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "1480x720_60.00"

    # Z Fold 4
    ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2176x1812_120.00"  708.75  2176 2368 2608 3040  1812 1815 1825 1944 -hsync +vsync
    ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2176x1812_120.00"


    ## 25%
    ${pkgs.xorg.xrandr}/bin/xrandr --newmode "1088x906"  173.75  1088 1176 1288 1488  906 909 919 974 -hsync +vsync
    ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "1088x906"  

    ${pkgs.xorg.xrandr}/bin/xrandr --newmode "872x726"  110.00  872 936 1024 1176  726 729 739 781 -hsync +vsync
    ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "872x726"  

    ${pkgs.xorg.xrandr}/bin/xrandr --newmode "1296x1080_120.00"  249.25  1296 1408 1544 1792  1080 1083 1093 1160 -hsync +vsync
    ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "1296x1080_120.00"

    # Pixel 3
    ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2160x1080_60.00"  194.50  2160 2304 2528 2896  1080 1083 1093 1120 -hsync +vsync
    ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2160x1080_60.00"

    ## 0.5x
    ${pkgs.xorg.xrandr}/bin/xrandr --newmode "1080x540_60.00"   46.00  1080 1120 1224 1368  540 543 553 562 -hsync +vsync
    ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "1080x540_60.00"

    # Galaxy Tab 8


    ## 17% (~720p)
    ${pkgs.xorg.xrandr}/bin/xrandr --newmode "1152x721"  145.75  1152 1240 1360 1568  721 724 734 776 -hsync +vsync
    ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "1152x721"

    ## 25%
    
    ${pkgs.xorg.xrandr}/bin/xrandr --newmode "1400x876"  215.75  1400 1512 1656 1912  876 879 889 942 -hsync +vsync
    ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "1400x876"

    ## 38% (~1080p)
    ${pkgs.xorg.xrandr}/bin/xrandr --newmode "1728x1081"  332.00  1728 1872 2056 2384  1081 1084 1094 1161 -hsync +vsync
    ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "1728x1081"

    ## 42%

    ${pkgs.xorg.xrandr}/bin/xrandr --newmode "1816x1136"  172.25  1816 1936 2128 2440  1136 1139 1149 1178 -hsync +vsync
    ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "1816x1136"

    ## 50%

    ${pkgs.xorg.xrandr}/bin/xrandr --newmode "1960x1226"  428.00  1960 2128 2336 2712  1226 1229 1239 1316 -hsync +vsync
    ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "1960x1226"
  '';
}
