{ config, pkgs, ... }:

{
  home.stateVersion = "24.11";

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableNushellIntegration = true;
    config = {
      whitelist.prefix = [ "/home/simonwjackson/code" ];
    };
  };

  programs.atuin = {
    enable = true;
    enableBashIntegration = true;
    enableNushellIntegration = true;
    daemon.enable = true;
    settings = {
      auto_sync = true;
      enter_accept = true;
      filter_mode_shell_up_key_binding = "workspace";
      inline_height = 10;
      search_mode = "fuzzy";
      secrets_filter = false;
      style = "compact";
      sync_address = "https://api.atuin.sh";
      sync_frequency = "5m";
    };
  };

  programs.nushell = {
    enable = true;
    configFile.text = ''
      $env.config = {
        show_banner: false
        edit_mode: emacs
        
        completions: {
          case_sensitive: false
          quick: true
          partial: true
          algorithm: fuzzy
        }

        table: {
          mode: rounded
          index_mode: auto
        }

        history: {
          max_size: 100_000
          sync_on_enter: true
          file_format: sqlite
        }
      }
    '';
    envFile.text = ''
      $env.PATH = ($env.PATH | split row (char esep)
        | prepend "/run/current-system/sw/bin"
        | prepend "/etc/profiles/per-user/simonwjackson/bin"
        | prepend $"($env.HOME)/.local/bin"
        | prepend $"($env.HOME)/.nix-profile/bin"
        | uniq)
    '';
    shellAliases = {
      ll = "ls -l";
      la = "ls -a";
      lla = "ls -la";
      g = "git";
      gs = "git status";
      gd = "git diff";
      gl = "git log --oneline -20";
      gp = "git push";
      gc = "git commit";
      rebuild = "sudo nixos-rebuild switch --flake ~/code/fuji";
    };
  };

  programs.carapace = {
    enable = true;
    enableNushellIntegration = true;
  };

  programs.starship = {
    enable = true;
    enableNushellIntegration = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$nix_shell$character";
      directory = {
        truncation_length = 3;
        style = "bold cyan";
      };
      git_branch = {
        format = "[$branch]($style) ";
        style = "bold purple";
      };
      git_status = {
        format = "[$all_status$ahead_behind]($style) ";
        style = "bold red";
      };
      nix_shell = {
        format = "[$symbol$state]($style) ";
        symbol = "❄️ ";
      };
      character = {
        success_symbol = "[›](bold green)";
        error_symbol = "[›](bold red)";
      };
    };
  };

  programs.bash = {
    enable = true;
  };

  programs.git = {
    enable = true;
    userName = "Simon W. Jackson";
    userEmail = "simon@simonwjackson.io";
  };
}
