{pkgs, ...}: {
  mountainous.hyprland = {
    enable = true;
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
  programs.git.extraConfig = {
    init.defaultBranch = "main";
  };

  programs.direnv.enable = true;

  home.packages = with pkgs; [
    neovim
    git
  ];
}
