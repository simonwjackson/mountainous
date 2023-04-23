{ config, lib, pkgs, modulesPath, ... }: {
  imports = [
    <nixos-hardware/dell/xps/17-9700/nvidia>
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "usbhid" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];
  # boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
  # boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ "kvm-intel" "uinput" ];
  # boot.extraModulePackages = [ config.boot.kernelPackages.rtl88x2bu config.boot.kernelPackages.rtl8814au ];
  boot.kernelPackages = pkgs.linuxPackages_zen;

  # boot.kernelPackages = pkgs.linuxPackagesFor (pkgs.linux_5_15.override {
  #   argsOverride = rec {
  #     src = pkgs.fetchurl {
  #           url = "mirror://kernel/linux/kernel/v5.x/linux-${version}.tar.xz";
  #           sha256 = "sha256-gPzZ76RDUC3p4nUPbftZ6N5Dpdh6bSvgncp0jXm18u4=";
  #     };
  #     version = "5.15.86";
  #     modDirVersion = "5.15.86";
  #   };
  # });

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;

  services.xserver.displayManager.setupCommands = ''
      # Galaxy S8 Ultra
      
      ## With notch
      ### 1x
      ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2960x1848_120.00"  985.50  2960 3224 3552 4144  1848 1851 1861 1982 -hsync +vsync
      ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2960x1848_120.00"
      ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2960x1848_90.00"  720.50  2960 3216 3536 4112  1848 1851 1861 1948 -hsync +vsync
      ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2960x1848_90.00"
      ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2960x1848_60.00"  466.75  2960 3192 3512 4064  1848 1851 1861 1915 -hsync +vsync
      ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2960x1848_60.00" 
      ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2960x1848_30.00"  221.25  2960 3128 3440 3920  1848 1851 1861 1883 -hsync +vsync
      ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2960x1848_30.00"
      
      ### 0.5x
      ${pkgs.xorg.xrandr}/bin/xrandr --newmode "1480x924_30.00"   52.25  1480 1520 1664 1848  924 927 937 943 -hsync +vsync
      ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "1480x924_30.00"
      ${pkgs.xorg.xrandr}/bin/xrandr --newmode "1480x924_60.00"  112.50  1480 1568 1720 1960  924 927 937 959 -hsync +vsync
      ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "1480x924_60.00"
      ${pkgs.xorg.xrandr}/bin/xrandr --newmode "1480x924_90.00"  176.25  1480 1592 1744 2008  924 927 937 976 -hsync +vsync
      ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "1480x924_90.00"
      ${pkgs.xorg.xrandr}/bin/xrandr --newmode "1480x924_120.00"  242.75  1480 1600 1760 2040  924 927 937 993 -hsync +vsync
      ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "1480x924_120.00"
      
      ## Without Notch
      ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2960x1820_30.00"  217.75  2960 3128 3440 3920  1820 1823 1833 1854 -hsync +vsync
      ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2960x1820_30.00"
      ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2960x1820_60.00"  459.50  2960 3192 3512 4064  1820 1823 1833 1886 -hsync +vsync
      ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2960x1820_60.00"
      ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2960x1820_90.00"  709.75  2960 3216 3536 4112  1820 1823 1833 1918 -hsync +vsync
      ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2960x1820_90.00"
      ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2960x1820_120.00"  970.50  2960 3224 3552 4144  1820 1823 1833 1952 -hsync +vsync
      ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2960x1820_120.00"
      
      # Note 9
      
      ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2960x1440_60.00"  361.00  2960 3176 3496 4032  1440 1443 1453 1493 -hsync +vsync
      ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2960x1440_60.00"
      
      ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2960x1440_30.00"  169.00  2960 3096 3400 3840  1440 1443 1453 1468 -hsync +vsync
      ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2960x1440_30.00"
      
      # Z Fold 2
      
      ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2208x1768_120.00"  702.50  2208 2408 2648 3088  1768 1771 1781 1897 -hsync +vsync
      ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2208x1768_120.00"
      
      ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2208x1768_90.00"  515.00  2208 2400 2640 3072  1768 1771 1781 1864 -hsync +vsync
      ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2208x1768_90.00"
      
      ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2208x1768_60.00"  332.25  2208 2376 2616 3024  1768 1771 1781 1832 -hsync +vsync
      ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2208x1768_60.00"
      
      ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2208x1768_30.00"  157.25  2208 2336 2560 2912  1768 1771 1781 1801 -hsync +vsync
      ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2208x1768_30.00"
      
      ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2120x1768_120.00"  675.25  2120 2312 2544 2968  1768 1771 1781 1897 -hsync +vsync
      ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2120x1768_120.00"
      
      ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2120x1768_90.00"  495.00  2120 2304 2536 2952  1768 1771 1781 1864 -hsync +vsync
      ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2120x1768_90.00"
      
      ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2120x1768_60.00"  319.00  2120 2288 2512 2904  1768 1771 1781 1832 -hsync +vsync
      ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2120x1768_60.00"
      
      ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2120x1768_30.00"  150.75  2120 2240 2456 2792  1768 1771 1781 1801 -hsync +vsync
      ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2120x1768_30.00"

      # Z Fold 4
      xrandr --newmode "2176x1812_120.00"  708.75  2176 2368 2608 3040  1812 1815 1825 1944 -hsync +vsync
      ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2176x1812_120.00"

      xrandr --newmode "2176x1812_60.00"  336.75  2176 2352 2584 2992  1812 1815 1825 1877 -hsync +vsync
      ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2176x1812_60.00"

      # Pixel 3
      ${pkgs.xorg.xrandr}/bin/xrandr --newmode "2160x1080_60.00"  194.50  2160 2304 2528 2896  1080 1083 1093 1120 -hsync +vsync
      ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "2160x1080_60.00"

      ## 0.5x
      ${pkgs.xorg.xrandr}/bin/xrandr --newmode "1080x540_60.00"   46.00  1080 1120 1224 1368  540 543 553 562 -hsync +vsync
      ${pkgs.xorg.xrandr}/bin/xrandr --addmode "DP-1" "1080x540_60.00"
'';

  # Includes the Wi-Fi and Bluetooth firmware
  hardware.enableRedistributableFirmware = true;

  # hardware.nvidia.modesetting.enable = true;
  hardware.opengl.enable = true;

  hardware.nvidia.prime.offload.enable = lib.mkForce true;

  services.xserver.videoDrivers = [ "nvidia" ];

  # Optionally, you may need to select the appropriate driver version for your specific GPU.
  hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.production;

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
