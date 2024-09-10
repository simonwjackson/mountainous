{lib, ...}: let
  inherit (lib.snowfall.fs) get-file;
in {
  syncthing = rec {
    otherDevices = {
      "Android Phone (usu)" = {
        device = {
          id = "CZA4RS5-6DZRRHR-4EMUXGK-WZO7KUR-5AUAOAX-TV6CCUX-MLCMBKY-64NJ4AC";
        };
        folders = [
          "notes"
          "gaming-profiles"
        ];
      };
    };
  };
}
