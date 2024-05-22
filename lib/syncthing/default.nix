{lib, ...}: let
  inherit (lib.snowfall.fs) get-file;
in {
  syncthing = rec {
    otherDevices = {
      "Android Phone (usu)" = {
        device = {
          id = "OHG43Z6-BVJN3ZT-GIM226G-5KX3PWJ-OBDDH5X-EMJPI7K-A3SGNCM-XVACBAG";
        };
        folders = [
          "notes"
          "gaming-profiles"
        ];
      };
    };
  };
}
