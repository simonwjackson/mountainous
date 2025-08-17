{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.mountainous.starship;
in {
  options.mountainous.starship = {
    enable = mkEnableOption "Whether to enable Starship prompt";
  };

  config = mkIf cfg.enable {
    programs.starship = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;

      settings = {
        format = "$all$character";
        
        character = {
          success_symbol = "[❯](bold #a6d189)";
          error_symbol = "[❯](bold #e78284)";
          vimcmd_symbol = "[❮](bold #a6d189)";
        };

        directory = {
          style = "bold #8caaee";
          truncation_length = 3;
          truncate_to_repo = true;
          format = "[$path]($style)[$read_only]($read_only_style) ";
          read_only = " 󰌾";
          read_only_style = "#e78284";
        };

        git_branch = {
          style = "bold #ca9ee6";
          format = "on [$symbol$branch]($style) ";
          symbol = " ";
        };

        git_status = {
          style = "#e5c890";
          ahead = "⇡\${count}";
          diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
          behind = "⇣\${count}";
          conflicted = "🏳";
          untracked = "?";
          stashed = "$";
          modified = "!";
          staged = "+";
          renamed = "»";
          deleted = "✘";
        };

        cmd_duration = {
          min_time = 2000;
          style = "#f4b8e4";
          format = "took [$duration]($style) ";
        };

        hostname = {
          ssh_only = true;
          style = "bold #81c8be";
          format = "[$hostname]($style) in ";
        };

        username = {
          style_user = "#f2d5cf";
          style_root = "bold #e78284";
          format = "[$user]($style) ";
          show_always = false;
        };

        package = {
          disabled = false;
          style = "#ef9f76";
          format = "is [\$symbol\$version]($style) ";
        };

        nodejs = {
          style = "#a6d189";
          format = "via [\$symbol(\$version )]($style)";
        };

        python = {
          style = "#e5c890";
          format = "via [\$symbol\$pyenv_prefix(\$version )(\$virtualenv )]($style)";
        };

        rust = {
          style = "#ef9f76";
          format = "via [\$symbol(\$version )]($style)";
        };

        nix_shell = {
          style = "#ca9ee6";
          format = "via [\$symbol\$state( \$name)]($style) ";
          symbol = "❄️ ";
        };

        battery = {
          full_symbol = "🔋 ";
          charging_symbol = "⚡️ ";
          discharging_symbol = "💀 ";
          display = [
            {
              threshold = 15;
              style = "bold #e78284";
            }
            {
              threshold = 50;
              style = "bold #e5c890";
            }
          ];
        };

        time = {
          disabled = true;
          style = "#838ba7";
          format = "🕙[\$time]($style) ";
        };
      };
    };
  };
}