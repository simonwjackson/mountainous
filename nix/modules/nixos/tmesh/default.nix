{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.mountainous.tmesh;
in {
  options.mountainous.tmesh = {
    enable = mkEnableOption "tmesh - tmux session manager";
  };

  config = mkIf cfg.enable {
    environment.sessionVariables = {
      TMESH_CMD = "nvim --cmd 'let g:auto_session_enabled = v:false' --cmd 'autocmd TermClose * if !v:event.status | quit | endif' --cmd 'autocmd VimEnter * set signcolumn=no | startinsert' +terminal";
    };

    programs.tmesh = {
      enable = true;

      # Optional: Custom tmux config for tmesh server
      tmeshServerTmuxConfig = ''
        # INFO: https://github.com/tmux/tmux/wiki/Clipboard#terminal-support---tmux-inside-tmux
        set -s set-clipboard on

        # allow passthrough of escape sequences
        set -g allow-passthrough on

        # Switch to another session if last window closed
        set-option -g detach-on-destroy off

        # Disable right click menu
        unbind-key -T root MouseDown3Pane

        # Respond to focus events
        set-option -g focus-events on

        # address vim mode switching delay (http://superuser.com/a/252717/65504)
        set-option -s escape-time 0

        # silent
        set-option -g visual-activity off
        set-option -g visual-bell off
        set-option -g visual-silence off
        set-option -g bell-action none

        # Ignore window notifications
        set-window-option -g monitor-activity off
        # Auto resize to the latest window
        set-option -g window-size latest

        # Window options
        setw -g aggressive-resize on
        setw -g mode-keys vi

        # Disable all the status bar stuff
        set -g status off

        #####################

        # Terminal settings
        set -sa terminal-features ',xterm-256color:RGB'

        # Enable 24-bit true color support
        set-option -g default-terminal "tmux-256color"
        set-option -ga terminal-overrides ",*256col*:Tc"

        # Mouse support
        set-option -g mouse on

        # Window and pane indexing
        set-option -g base-index 1
        set-option -g pane-base-index 1
        set-option -g renumber-windows on

        # Status bar
        set-option -g status off

        # Clipboard and system integration
        set-option -g set-clipboard on
        set-option -g focus-events on
        set-option -g escape-time 0
        set-option -g history-limit 0

        # Catppuccin Frappe theme colors - Server variant
        set-option -g pane-border-style "fg=#737994"
        set-option -g pane-active-border-style "fg=#ca9ee6"
        set-option -g mode-style "fg=#303446,bg=#e5c890"
        set-option -g message-style "fg=#c6d0f5,bg=#51576d"
        set-option -g message-command-style "fg=#c6d0f5,bg=#51576d"
        set-option -g popup-style "fg=#c6d0f5,bg=#292c3c"
        set-option -g popup-border-style "fg=#ca9ee6"
        set-option -g popup-border-lines "rounded"
        set-option -g menu-style "fg=#c6d0f5,bg=#51576d"
        set-option -g menu-selected-style "fg=#303446,bg=#ca9ee6"
        set-option -g menu-border-style "fg=#737994"
        set-option -g menu-border-lines "rounded"
      '';

      # Custom tmux config for tmesh
      tmeshTmuxConfig = ''
        # Terminal settings
        set-option -g default-terminal "tmux-256color"
        set-option -ga terminal-overrides ",*256col*:Tc"

        # Mouse support
        set-option -g mouse on

        # Window and pane indexing
        set-option -g base-index 1
        set-option -g pane-base-index 1
        set-option -g renumber-windows on

        # Status bar
        set-option -g status off

        # Clipboard and system integration
        set-option -g set-clipboard on
        set-option -g focus-events on
        set-option -g escape-time 0
        set-option -g history-limit 0

        # Catppuccin Frappe theme colors
        set-option -g pane-border-style "fg=#626880"
        set-option -g pane-active-border-style "fg=#8caaee"
        set-option -g mode-style "fg=#303446,bg=#babbf1"
        set-option -g message-style "fg=#c6d0f5,bg=#414559"
        set-option -g message-command-style "fg=#c6d0f5,bg=#414559"
        set-option -g popup-style "fg=#c6d0f5,bg=#303446"
        set-option -g popup-border-style "fg=#8caaee"
        set-option -g popup-border-lines "rounded"
        set-option -g menu-style "fg=#c6d0f5,bg=#414559"
        set-option -g menu-selected-style "fg=#303446,bg=#8caaee"
        set-option -g menu-border-style "fg=#626880"
        set-option -g menu-border-lines "rounded"
      '';
    };
  };
}
