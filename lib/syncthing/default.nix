{lib, ...}: let
  inherit (lib.snowfall.fs) get-file;
in {
  syncthing = rec {
    otherDevices = {
      "Watch (bandi)" = {
        device = {
          id = "HMVJB6K-VYTB4ZV-EVUJLXF-A55M67M-FFW3CUP-Q73NHVD-GBNHWNL-SFOD4QQ";
        };
        shares = [
          "music"
        ];
      };

      "Tab Ultra (naka)" = {
        device = {
          id = "6SDMTLX-5YQ3QIK-5ZJNOQV-IZZK5O2-VC2QYK2-VKEAKY5-G5PZBXK-AV6RXAR";
        };
        shares = [
          "notes"
          "games"
          "gaming-profiles"
          "music"
        ];
      };

      "Retroid 5 Mini (sobo)" = {
        device = {
          id = "BPLYMBL-HBATFIY-N57S56U-MHCQ3IU-BE7LGEY-TCA726B-IGMIRRL-HSO4CAV";
        };
        shares = [
          "gaming-profiles"
          "games"
          "music"
        ];
      };

      "Phone (usu)" = {
        device = {
          id = "53O3J7A-V6MHS3X-VFV5S36-SOIAQBF-YMNE7FK-YQRRRKG-VISKFD7-XWSQPQD";
        };
        shares = [
          "notes"
          "gaming-profiles"
          "music"
        ];
      };
    };
  };
}
