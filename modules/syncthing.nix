{
  services.syncthing = {
    overrideDevices = true;
    overrideFolders = true;
    enable = true;
    user = "simonwjackson";
    configDir = "/home/simonwjackson/.config/syncthing";

    devices = {
      ushiro.id = "MIB5GJT-FQWMJ35-EWHDI2O-3IHBOLC-6H5RC6I-I7MEVY7-FQ7MEPO-P3YMCQJ";
      unzen.id = "QKHBVLD-BCDANSP-ED76TFN-JN4U6CF-KOHSUFP-YREMPYV-V7BZG32-BRXV2AV";
      kuro.id = "4YUE3JH-CUR4TTS-RVTNUHZ-2HDENB3-FH3VWIJ-TMCW3X5-JSPKLXB-H2QUEAP";
      haku.id = "XAQBGPZ-5CVMY23-43CAQ5P-QFGGPJS-LCYKSE6-HEFFQM7-XRAIF6E-5XHAWQT";
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
      documents.devices = [ "kuro" "unzen" ];
      code.devices = [ "ushiro" "unzen" ];
    };
  };
}
