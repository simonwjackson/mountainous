{lib, ...}: let
  inherit (lib.snowfall.fs) get-file;
in {
  syncthing = rec {
    otherDevices = {
      "Tab Ultra (naka)" = {
        device = {
          id = "6SDMTLX-5YQ3QIK-5ZJNOQV-IZZK5O2-VC2QYK2-VKEAKY5-G5PZBXK-AV6RXAR";
        };
        shares = [
          "notes"
          "games"
          "gaming-profiles"
        ];
      };

      "Retroid 5 Mini (sobo)" = {
        device = {
          id = "KLO2TTI-WXWHNGD-TVMIUIH-4VF7ERL-NMPWDVU-NN7BLIY-BA42ELZ-RO4VBQK";
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
