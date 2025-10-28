{pkgs, ...}: {
  # Home-manager configuration for asana

  # Enable Hyprland home-manager module
  mountainous.hyprland = {
    enable = true;
  };

  programs.git = {
    enable = true;
    extraConfig = {
      init.defaultBranch = "main";
    };
  };

  programs.direnv.enable = true;

  home.packages = with pkgs; [
    neovim
  ];
}
