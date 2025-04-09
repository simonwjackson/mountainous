{lib, ...}: let
  inherit (lib.mountainous) enabled;

  codeDir = "/snowscape/code";
in {
  boot = {
    kernelModules = [
      "nvme"
    ];
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
      };
    };
  };

  # disko.devices.disk.sleet = {
  #   type = "disk";
  #   # device = "/dev/disk/by-id/usb-Generic_STORAGE_DEVICE_000000000819-0:0";
  #   device = "/dev/disk/by-id/usb-Generic_STORAGE_DEVICE_000000000819-0:0-part1";
  #   content = {
  #     type = "gpt";
  #     partitions = {
  #       data = {
  #         size = "100%";
  #         content = {
  #           format = "f2fs";
  #           mountOptions = ["noatime" "noauto"];
  #           mountpoint = "/tundra/sleet";
  #           type = "filesystem";
  #         };
  #       };
  #     };
  #   };
  # };

  mountainous = {
    boot = enabled;
    disks = {
      frostbite = {
        enable = true;
        device = "/dev/disk/by-id/nvme-WDSN740-SDDPNQD-1T00-1004_22501B805583";
        swapSize = "16G";
      };
    };
    gaming = {
      core = enabled;
      steam = enabled;
    };
    hardware = {
      devices.samsung-galaxy-book3-360 = enabled;
    };
    impermanence = {
      enable = true;
    };
    networking.core.names = [
      {
        name = "wifi";
        mac = "d4:d8:53:90:2b:6c";
      }
    ];
    profiles = {
      base = enabled;
      laptop = enabled;
      workspace = enabled;
    };
    # snowscape = {
    #   enable = true;
    #   glacier = "unzen";
    #   paths = [
    #     "/avalanche/volumes/blizzard"
    #     "/avalanche/disks/sleet/0/00"
    #   ];
    # };
  };

  fileSystems."/snowscape" = {
    device = "/tundra/frostbite/snowscape";
    fsType = "none";
    options = ["bind"];
    neededForBoot = false;
  };

  # INFO: This is a temporary hack to get the syncthing service working. For some reason, the
  # `notes` and `code` directories are not showing up in the web UI.

  environment.etc."snowscape-stignore" = {
    target = "${codeDir}/.stignore";
    text = ''
      # Node.js
      "node_modules/"

      # Build outputs
      "dist/"
      "build/"
      "out/"
      ".next/"
      ".nuxt/"
      ".output/"

      # Environment and config
      ".env.local"
      ".env.*.local"
      "config.local.js"
      "*.local.json"

      # Dependencies and package managers
      "vendor/"
      "composer.phar"
      "Pipfile.lock"
      "poetry.lock"
      "package-lock.json"
      "yarn.lock"
      "pnpm-lock.yaml"

      # IDE and editor files
      ".idea/"
      "*.swp"
      "*.swo"
      ".project"
      ".settings/"
      ".classpath"
      ".factorypath"

      # Testing and coverage
      "coverage/"
      ".nyc_output/"
      ".coverage"
      "htmlcov/"
      ".pytest_cache/"
      "__pycache__/"
      "*.py[cod]"
      ".tox/"

      # Logs and databases
      "*.log"
      "*.sqlite"
      "*.sqlite3"
      "*.db"
      "logs/"
      "*.log.*"

      # Temporary files
      "tmp/"
      "temp/"
      ".temp/"
      "*.tmp"
      "*.bak"
      "*.swp"
      "*.swo"

      # Binary and compiled files
      "*.class"
      "*.dll"
      "*.exe"
      "*.o"
      "*.so"
      "*.dylib"
      "*.jar"
      "*.war"
      "*.ear"
      "*.zip"
      "*.tar.gz"
      "*.rar"

      # Mobile development
      ".gradle/"
      "*.apk"
      "*.aab"
      "*.ipa"
      "*.dSYM.zip"
      "*.dSYM"

      "# Documentation"
      "docs/_build/"
      "site/"

      # Cache
      ".cache/"
      ".parcel-cache/"
      ".eslintcache"
      ".stylelintcache"
      "*.cache"

      # Misc
      "Thumbs.db"
      "ehthumbs.db"
      "*~"
      ".DS_Store"
      "DELETEME"
    '';
    mode = "0644";
  };

  services.syncthing.settings.folders = {
    "notes" = {
      path = "/snowscape/notes";
      devices = ["aka" "unzen"];
    };
    "code" = {
      path = codeDir;
      devices = ["aka" "unzen"];
    };
  };

  system.stateVersion = "24.11";
}
