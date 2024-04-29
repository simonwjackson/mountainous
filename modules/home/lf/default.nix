{...}: {
  programs.lf = {
    enable = true;
    extraConfig = builtins.readFile ./lfrc;
  };

  home.file = {
    "./.local/bin/pv" = {
      source = ./pv.sh;
    };

    "./.config/lf/colors" = {
      source = ./colors;
    };

    "./.config/lf/icons" = {
      source = ./icons;
    };
  };
}
