{pkgs, ...}: {
  # Minimal home-manager configuration for Oracle cloud instance

  programs.git = {
    enable = true;
    extraConfig = {
      init.defaultBranch = "main";
    };
  };

  programs.direnv.enable = true;

  home.packages = with pkgs; [
    # Minimal tools
    neovim
  ];

  # Basic shell configuration will be inherited from base profile
}
