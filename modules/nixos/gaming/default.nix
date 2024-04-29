{
  lib,
  config,
  pkgs,
  ...
}: let
  snowscape = "/glacier/snowscape";
  steamApps = "${snowscape}/gaming/games/steam/steamapps";
  steamAppsOverlay = "/home/simonwjackson/.var/app/com.valvesoftware.Steam/data/Steam/steamapps";
  mountpoint = "${pkgs.util-linux}/bin/mountpoint";
  mount = "${pkgs.mount}/bin/mount";
in {
  environment.systemPackages = with pkgs; [
    yuzu-mainline
    citra-canary
    cemu
    retroarchFull
    dolphinEmu
    rpcs3
  ];

  programs.gamemode = {
    enable = true;
    enableRenice = true;
    settings = {
      custom = {
        start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
        end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
      };

      general = {
        softrealtime = "on";
        inhibit_screensaver = 1;
        renice = 10;
      };

      # gpu = {
      #   apply_gpu_optimisations = "accept-responsibility";
      #   gpu_device = 0;
      #   amd_performance_level = "high";
      # };
    };
  };

  services.flatpak.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-kde
    ];
  };
  services.flatpak.remotes = lib.mkOptionDefault [
    {
      name = "flathub";
      location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
    }
  ];
  services.flatpak.packages = [
    "com.valvesoftware.Steam"
    "com.valvesoftware.Steam.CompatibilityTool.Proton-GE"
    "org.freedesktop.Platform.VulkanLayer.MangoHud/x86_64/23.08"
    "org.freedesktop.Platform.VulkanLayer.gamescope/x86_64/23.08"
  ];

  systemd.services.mountSteamAppsOverlay = {
    # after = ["mountSnowscape.service"];
    script = ''
      ${mountpoint} -q ${steamAppsOverlay} || ${mount} --bind ${steamApps} ${steamAppsOverlay}
    '';
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
    };
  };

  # BUG: if dirs dont exist, they are owned by root
  fileSystems = {
    "/home/simonwjackson/.local/share/dolphin-emu/GC" = {
      device = "${snowscape}/gaming/profiles/simonwjackson/progress/saves/nintendo-gamecube/";
      options = ["bind"];
    };

    "/home/simonwjackson/.local/share/dolphin-emu/Wii/title" = {
      device = "${snowscape}/gaming/profiles/simonwjackson/progress/saves/nintendo-wii/";
      options = ["bind"];
    };

    "/home/simonwjackson/.local/share/Cemu/mlc01/usr" = {
      device = "${snowscape}/gaming/profiles/simonwjackson/progress/saves/nintendo-wiiu/";
      options = ["bind"];
    };

    "/home/simonwjackson/.local/share/yuzu/sdmc" = {
      device = "${snowscape}/gaming/profiles/simonwjackson/progress/saves/nintendo-switch/sdmc";
      options = ["bind"];
    };

    "/home/simonwjackson/.local/share/yuzu/shader" = {
      device = "${snowscape}/gaming/launchers/yuzu/shader";
      options = ["bind"];
    };

    "/home/simonwjackson/.local/share/yuzu/keys" = {
      device = "${snowscape}/gaming/systems/nintendo-switch/keys";
      options = ["bind"];
    };

    "/home/simonwjackson/.local/share/yuzu/nand" = {
      device = "${snowscape}/gaming/profiles/simonwjackson/progress/saves/nintendo-switch/nand";
      options = ["bind"];
    };
  };
}
