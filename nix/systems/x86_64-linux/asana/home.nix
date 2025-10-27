{pkgs, ...}: {
  # Minimal home-manager configuration

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
