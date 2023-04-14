{ pkgs, ... }:

let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz";
in
{
  imports = [
    (import "${home-manager}/nixos")
  ];

  users.users.simonwjackson = {
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "Simon W. Jackson";
    extraGroups = [
      "adbusers"
      "docker"
      "networkmanager"
      "wheel"
    ];
  };

  home-manager.users.simonwjackson = { config, pkgs, ... }: {

    home = {
      stateVersion = "23.05";
      username = "simonwjackson";
      homeDirectory = "/home/simonwjackson";
      sessionVariables = {
        FZF_DEFAULT_OPTS = "--reverse --layout=reverse --color=bg+:-1 --ansi --marker='❖' --pointer='❯' --prompt='  '";
        MPV_SOCKET = "/run/user/\$(id -u)/mpv.socket";
        GITHUB_TOKEN = builtins.getEnv ("GITHUB_TOKEN");
        GITHUB_USER = builtins.getEnv ("GITHUB_USER");
        OPENAI_API_KEY = builtins.getEnv ("OPENAI_API_KEY");
        GDK_SCALE = if (builtins.getEnv ("NIX_CONFIG_HIDPI") == "1") then 2 else 1;
        GDK_DPI_SCALE = if (builtins.getEnv ("NIX_CONFIG_HIDPI") == "1") then 0.5 else 1;
        QT_AUTO_SCREEN_SET_FACTOR = 1;
        QT_QPA_PLATFORMTHEME = "qt5ct";
        QT_SCALE_FACTOR = if (builtins.getEnv ("NIX_CONFIG_HIDPI") == "1") then 2 else 1;
        QT_FONT_DPI = 96;
      };
    };
  };
}
