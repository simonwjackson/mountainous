{
  services.syncthing = {
    enable = true;
    # overrideDevices = true;
    # overrideFolders = true;
    user = "simonwjackson";
    configDir = "/home/simonwjackson/.config/syncthing";

    devices = {
      fiji.id = builtins.getEnv "SYNCTHING_FIJI_ID";
      haku.id = builtins.getEnv "SYNCTHING_HAKU_ID";
      kita.id = builtins.getEnv "SYNCTHING_KITA_ID";
      kuro.id = builtins.getEnv "SYNCTHING_KURO_ID";
      unzen.id = builtins.getEnv "SYNCTHING_UNZEN_ID";
      yari.id = builtins.getEnv "SYNCTHING_YARI_ID";
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
