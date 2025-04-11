{pkgs, ...}: {
mountainous.hyprland = {
  enable = true;
};

  # Additional packages specific to this system
  home.packages = with pkgs; [
    neovim
    ex  # Example extraction utility package from packages directory
  ];

  # System-specific settings
  programs.git.extraConfig = {
    init.defaultBranch = "main";
  };

  # Enable modules
  modules = {
    my-home-manager-module.enable = true;
  };
}
