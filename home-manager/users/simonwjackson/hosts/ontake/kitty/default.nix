{lib, ...}: {
  home = {
    sessionVariables = {
      TERMINAL = "kitty";
    };
  };

  programs.kitty = {
    enable = true;
    extraConfig = builtins.readFile ./kitty.conf;
  };
}
