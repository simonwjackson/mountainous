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
      raiden.id = builtins.getEnv "SYNCTHING_RAIDEN_ID";
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
      # TODO: Add toggles for each folder
    };
  };
}
