{
  config,
  lib,
  ...
}: {
  services.syncthing = {
    overrideDevices = true;
    overrideFolders = true;
    # TODO: change this to mainUser
    user = "simonwjackson";
    configDir = "/home/simonwjackson/.config/syncthing";

    settings = {
      ignores = {
        "line" = [
          "**/node_modules"
          "**/build"
          "**/cache"
        ];
      };

      folderSettings = {
        notes = {
          devices = ["fiji" "unzen" "usu" "kita"];
        };

        gaming-profiles = {
          devices = ["usu" "kita" "zao" "unzen"];
        };
      };

      # Only setup shares that have been enabled in the host's config file
      folders = lib.mkMerge (
        lib.mapAttrsToList
        (name: value: {
          "${name}" = {
            path = value;
            devices = config.services.syncthing.settings.folderSettings."${name}".devices;
          };
        })
        config.services.syncthing.settings.paths
      );

      devices = {
        fiji = {
          id = "ABVHUQR-BIPNGCS-W7RGGEV-HBA3R4C-UWQAYWQ-KCBPJ6D-PIPLQYU-CXHOWAD";
          name = "laptop (fiji)";
        };

        unzen = {
          id = "ETEYYE4-C3P2L34-HIV54WA-XQRERGB-LXL5ZRZ-FVA4EXR-YUDRQVL-HV2FDQA";
          name = "home server (unzen)";
        };

        usu = {
          id = "OHG43Z6-BVJN3ZT-GIM226G-5KX3PWJ-OBDDH5X-EMJPI7K-A3SGNCM-XVACBAG";
          name = "phone (usu)";
        };

        yabashi = {
          id = "MX3MDCS-DBIX5DN-4KCI7IF-DY652C3-FYO3V33-HWPPUQU-HL4USN5-4JOQKQD";
          name = "remote server (yabashi)";
        };

        zao = {
          id = "CTOOG4Z-5WK7MDW-UQ3KHOI-YEMDGQF-D6JSIMG-BNPJZWN-MPN3RTO-TBFKRAN";
          name = "gaming (zao)";
        };

        kita = {
          id = "J6JEBGV-GDLTLZA-JKIS5PM-EYJ6IS5-QBDM3KP-LSGBR2D-S5VXSYE-TWMVYQ5";
          name = "gpd win (kita)";
        };
      };
    };

    extraFlags = [
      "--no-default-folder"
      # "--gui-address=0.0.0.0:8384"
    ];
  };
}
# gaming-profiles.versioning = {
#   type = "staggered";
#   params = {
#     cleanInterval = "3600";
#     maxAge = "31536000";
#   };
# };
