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
    commands = {
      "open" = "xdg-open";
      "push" = "git add %s && git commit -m 'push %s'";
      "touch" = "%touch $1 && lf -remote \"send $id load\" && lf -remote \"send $id select $1\"";
    };
    settings = {
      icons = true;
      tabstop = 4;
      number = false;
      ratios = "1:1:3";
    };
    cmdKeybindings = { };
    keybindings = {
      D = "delete";
      T = "push :touch<space>";
      gh = "cd ~";
      i = "$less $f";
      U = "!du -sh";
      "<enter>" = "open";
      "." = "set hidden!";
    };
    extraConfig = builtins.readFile ./lf/lfrc;
    previewer.source = pkgs.writeShellScript "pv.sh" ''
      #!/bin/sh

      case "$1" in
          *.tar*) tar tf "$1";;
          *.zip) 7z l "$1";;
          *.rar) 7z l "$1";;
          *.7z) 7z l "$1";;
          *.pdf) pdftotext "$1" -;;
          *) bat --color always --style=plain --paging=never "$1";;
      esac
    '';
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
