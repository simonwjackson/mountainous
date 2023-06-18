{ ... }:

let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz";
in
{
  imports = [
    (import "${home-manager}/nixos")
  ];

  home-manager.users.simonwjackson = { lib, config, pkgs, ... }: {
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
      shell_gpt
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
      # tmux.enableShellIntegration = true;
    };

    home.file = {
      "./.config/direnv/direnv.toml" = {
        source = ./direnv/direnv.toml;
      };

      "./.config/tmux/tmux.conf" = {
        source = ./tmux/tmux.conf;
      };

      "./.local/bin/find-then-edit" = {
        source = ./find-then-edit.sh;
        executable = true;
      };

      "./.local/bin/grep-then-edit" = {
        executable = true;
        source = ./grep-then-edit.sh;
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
  };
}
