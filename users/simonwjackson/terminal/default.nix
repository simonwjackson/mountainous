{ pkgs, ... }:

{
  imports = [
    ./development
  ];

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    sessionVariables = {
      TERM = "tmux-256color";
      TERMINAL = "kitty";
      EDITOR = "nvim";
      # PAGER = "nvimpager";
    };

  };

  home.packages = with pkgs; [
    # Terminal Utils
    exa
    btop
    dialog
    nmap
    fd
    # nvimpager
  ];

  programs.bat = {
    enable = true;

    themes = {
      dracula = builtins.readFile (pkgs.fetchFromGitHub
        {
          owner = "dracula";
          repo = "sublime"; # Bat uses sublime syntax for its themes
          rev = "26c57ec282abcaa76e57e055f38432bd827ac34e";
          sha256 = "019hfl4zbn4vm4154hh3bwk6hm7bdxbr1hdww83nabxwjn99ndhv";
        } + "/Dracula.tmTheme");
    };

    config = {
      theme = "Dracula";
      italic-text = "always";
    };
  };


  #     programs.bash.enable = true;

  programs.fzf = {
    enable = true;

    enableZshIntegration = true;
    enableBashIntegration = true;
    defaultCommand = "rg --files --hidden --follow --glob '!.git'";
    tmux.enableShellIntegration = true;
  };

  home.file = {
    "./.config/tmux/themes" = {
      recursive = true;
      source = ./tmux/themes;
    };
  };

  programs.tmux = {
    enable = true;

    plugins = with pkgs.tmuxPlugins; [
      sensible
      jump
      extrakto
      tmux-fzf
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-strategy-nvim 'session'
          set -g @resurrect-save 'a'
          set -g @resurrect-restore 'A'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-boot 'on'
          set -g @continuum-save-interval '60' # minutes
        '';
      }
    ];

    extraConfig = builtins.readFile (./tmux/tmux.conf);

  };

  home.file = {
    "./.config/direnv/direnv.toml" = {
      source = ./direnv/direnv.toml;
    };

    "./.config/tmux/share.tmux.conf" = {
      source = ./tmux/share.tmux.conf;
    };

    "./.local/bin/pv" = {
      source = ./lf/pv.sh;
    };

    "./.config/lf/colors" = {
      source = ./lf/colors;
    };

    "./.config/lf/icons" = {
      source = ./lf/icons;
    };
  };

  programs.lf = {
    enable = true;
    extraConfig = builtins.readFile ./lf/lfrc;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
