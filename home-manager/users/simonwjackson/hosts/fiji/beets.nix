{ lib, config, ... }: {
  programs.beets = {
    enable = true;
    settings = {
      match = {
        strong_rec_thresh = 0.20;
      };

      clutter = [ "*" ];
      plugins = lib.strings.concatStringsSep " " [
        "bpd"
        "export"
        "duplicates"
        "missing"
      ];

      import = {
        duplicate_action = "merge";
      };

      duplicates = {
        tiebreak = {
          items = [ "bitrate" ];
        };
      };

      paths = {
        default = "$album - $albumartist [$year]/$track - $title";
        singleton = "Non-Album/$artist - $title";
        comp = "Compilations/$album%aunique{} [$year]/$track - $title";
      };

      directory = config.xdg.userDirs.music;
      library = "${config.xdg.dataHome}/musiclibrary.db";
    };
  };
}
