{ config, pkgs, ... }: {

  environment.systemPackages = with pkgs; [
    yuzu
    cemu
    retroarchFull
    dolphinEmu
  ];

  services.flatpak.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-kde
    ];
  };

  systemd.services.mountSteamAppsOverlay = {
    after = [ "mountTank.service" ];
    script = ''
      ${pkgs.util-linux}/bin/mountpoint -q /home/simonwjackson/.var/app/com.valvesoftware.Steam/data/Steam/steamapps || ${pkgs.mount}/bin/mount --bind /glacier/snowscape/gaming/games/steam/steamapps /home/simonwjackson/.var/app/com.valvesoftware.Steam/data/Steam/steamapps
    '';
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
    };
  };

  fileSystems = {
    "/home/simonwjackson/.local/share/dolphin-emu/GC" = {
      device = "/glacier/snowscape/gaming/profiles/simonwjackson/progress/saves/nintendo-gamecube/";
      options = [ "bind" ];
    };

    "/home/simonwjackson/.local/share/dolphin-emu/Wii/title" = {
      device = "/glacier/snowscape/gaming/profiles/simonwjackson/progress/saves/nintendo-wii/";
      options = [ "bind" ];
    };

    "/home/simonwjackson/.local/share/Cemu/mlc01/usr" = {
      device = "/glacier/snowscape/gaming/profiles/simonwjackson/progress/saves/nintendo-wiiu/";
      options = [ "bind" ];
    };

    "/home/simonwjackson/.local/share/yuzu/sdmc" = {
      device = "/glacier/snowscape/gaming/profiles/simonwjackson/progress/saves/nintendo-switch/sdmc";
      options = [ "bind" ];
    };

    "/home/simonwjackson/.local/share/yuzu/shader" = {
      device = "/glacier/snowscape/gaming/emulators/yuzu/shader";
      options = [ "bind" ];
    };

    "/home/simonwjackson/.local/share/yuzu/keys" = {
      device = "/glacier/snowscape/gaming/systems/nintendo-switch/keys";
      options = [ "bind" ];
    };

    "/home/simonwjackson/.local/share/yuzu/nand" = {
      device = "/glacier/snowscape/gaming/profiles/simonwjackson/progress/saves/nintendo-switch/nand";
      options = [ "bind" ];
    };
  };

}
