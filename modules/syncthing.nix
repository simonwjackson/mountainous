{
  services.syncthing = {
    enable = true;
    overrideDevices = true;
    overrideFolders = true;
    user = "simonwjackson";
    configDir = "/home/simonwjackson/.config/syncthing";

    devices = {
      fiji = {
        id = builtins.getEnv "SYNCTHING_FIJI_ID";
	name = "laptop (fiji)";
      };

      unzen = {
        id = builtins.getEnv "SYNCTHING_UNZEN_ID";
        name = "home server (unzen)";
      };

      zao = {
        id = builtins.getEnv "SYNCTHING_ZAO_ID";
	name = "gaming (zao)";
      };

      haku = {
        id = builtins.getEnv "SYNCTHING_HAKU_ID";
        name = "phone (haku)";
      };

      yari = {
        id = builtins.getEnv "SYNCTHING_YARI_ID";
        name = "tablet (yari)";
      };
    };

    extraFlags = [
      "--no-default-folder"
      "--gui-address=0.0.0.0:8384"
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
  };
}
