{ config, pkgs, ... }:

{
  imports = [ ];

  programs.zsh = {
    enable = true;
    autocd = true;
    dotDir = ".config/zsh";
    enableSyntaxHighlighting = true;
    enableAutosuggestions = true;
    enableCompletion = true;

    dirHashes = {
      docs = "$HOME/Documents";
      dl = "$HOME/Downloads";
    };

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "vi-mode" ];
      theme = "robbyrussell";
    };

    initExtra =
      builtins.readFile (./rc/base.zsh) +
      builtins.readFile (./rc/bindings.zsh);

    history = {
      save = 999999999;
      size = 999999999;
    };
  };
}
