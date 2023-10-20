{ ... }: {
  home.sessionVariables = {
    TERM = "tmux-256color";
  };

  home.file = {
    "./.config/tmux/tmux.shared.conf" = {
      source = ./tmux.shared.conf;
    };

    "./.config/tmux/tmux.host.conf" = {
      source = ./tmux.host.conf;
    };

    "./.config/tmux/tmux.workspace.conf" = {
      source = ./tmux.workspace.conf;
    };
  };
}
