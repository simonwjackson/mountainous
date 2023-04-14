{
  services.syncthing = {
    enable = true;
    overrideDevices = true;
    overrideFolders = true;
    user = "simonwjackson";
    configDir = "/home/simonwjackson/.config/syncthing";

    devices = {
      ushiro.id = builtins.getEnv "SYNCTHING_USHIRO_ID";
      unzen.id = builtins.getEnv "SYNCTHING_UNZEN_ID";
      kuro.id = builtins.getEnv "SYNCTHING_KURO_ID";
      haku.id = builtins.getEnv "SYNCTHING_HAKU_ID";
    };

    extraFlags = [
      "--no-default-folder"
    ];

    extraOptions = {
      ignores = {
        "line" = [
          "**/node_modules"
          "**/build"
          "**/cache"
        ];
      };
    };

    folders = {
      documents.devices = [ "kuro" "unzen" "ushiro" ];
      audiobooks.devices = [ "unzen" ];
      books.devices = [ "kuro" "unzen" ];
      gaming-profiles-simonwjackson.devices = [ "unzen" "kuro" "haku" ];
      music.devices = [ "unzen" ];
      code.devices = [ "unzen" "ushiro" ];
    };
  };
}
