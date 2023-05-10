let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz";
in
{
  imports = [
    (import "${home-manager}/nixos")
  ];

  home-manager.users.simonwjackson = { config, lib, pkgs, ... }:
    let
      cfg = config.programs.tmux-all-sessions;
    in
    {
      options.programs.tmux-all-sessions = {
        enable = lib.mkEnableOption "tmux-all-sessions";
      };

      config = lib.mkIf cfg.enable {
        home.packages = with pkgs; [
          tmux
          boxes
          fzf
          fd
        ];

        programs.tmux.extraConfig = lib.mkMerge [
          "bind-key -n 'M-S' display-popup -E -w 80% -h 80% $HOME/.local/bin/tmux-all-sessions"
        ];

        home.file.".local/bin/tmux-all-sessions" = {
          text = builtins.readFile ./tmux-all-sessions.sh;
          executable = true;
        };
      };
    };
}
