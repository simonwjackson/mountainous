{pkgs, ...}: {
  mountainous.hyprland = {
    extraSettings = {
      monitor = [
        ",preferred,auto,auto"
      ];
      exec-once = [
        "systemctl --user start hyprland-session.target"
      ];
    };
  };

  # System-specific settings
  programs.git.settings = {
    init.defaultBranch = "main";
  };

  programs.direnv.enable = true;

  home.packages = with pkgs; [
    neovim
    git
  ];
}
