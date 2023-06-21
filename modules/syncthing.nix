{
  services.syncthing = {
    enable = true;
    overrideDevices = true;
    overrideFolders = true;
    user = "simonwjackson";
    configDir = "/home/simonwjackson/.config/syncthing";

    devices = {
      fiji.id = builtins.getEnv "SYNCTHING_FIJI_ID";
      haku.id = builtins.getEnv "SYNCTHING_HAKU_ID";
      kuro.id = builtins.getEnv "SYNCTHING_KURO_ID";
      unzen.id = builtins.getEnv "SYNCTHING_UNZEN_ID";
      zao.id = builtins.getEnv "SYNCTHING_ZAO_ID";
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
