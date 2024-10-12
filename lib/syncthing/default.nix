{lib, ...}: let
  inherit (lib.snowfall.fs) get-file;
in {
  syncthing = rec {
    otherDevices = {
      "Retroid 5 Mini (sobo)" = {
        device = {
          id = "YFTZMZQ-SRZHXL7-2T4US52-KFPRR6K-VRBEQSN-E2L2KTE-W2HPERO-PJXILQX";
        };
        shares = [
          "gaming-profiles"
          "games"
        ];
      };
      "Phone (usu)" = {
        device = {
          id = "53O3J7A-V6MHS3X-VFV5S36-SOIAQBF-YMNE7FK-YQRRRKG-VISKFD7-XWSQPQD";
        };
        shares = [
          "notes"
          "gaming-profiles"
        ];
      };
      # "Android Phone (usu)" = {
      #   device = {
      #     id = "CZA4RS5-6DZRRHR-4EMUXGK-WZO7KUR-5AUAOAX-TV6CCUX-MLCMBKY-64NJ4AC";
      #   };
      #   shares = [
      #     "notes"
      #     "gaming-profiles"
      #   ];
      # };
    };
  };
}
