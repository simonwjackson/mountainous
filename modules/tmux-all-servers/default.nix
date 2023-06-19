let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz";
in
{
  imports = [
    (import "${home-manager}/nixos")
  ];

  home-manager.users.simonwjackson = { config, lib, pkgs, ... }:
    let
      cfg = config.programs.tmux-all-servers;
    in
    {
      options.programs.tmux-all-servers = {
        enable = lib.mkEnableOption "tmux-all-servers";
      };

      config = lib.mkIf cfg.enable {
        home.packages = with pkgs; [
          tmux
          boxes
          fzf
          fd
        ];

        home.file.".local/bin/tmux-all-servers" = {
          text = builtins.readFile ./tmux-all-servers.sh;
          executable = true;
        };
      };
    };
}
