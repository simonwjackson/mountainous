{
  config,
  lib,
  pkgs,
  osConfig ? {},
  ...
}: {
  config = {
    home.stateVersion = "24.11";

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableBashIntegration = true;
      config = {
        whitelist.prefix = ["/home/simonwjackson/code"];
      };
    };

    home.sessionPath = [
      "/run/wrappers/bin"
      "$HOME/.nix-profile/bin"
      "$HOME/.local/bin"
      "/etc/profiles/per-user/simonwjackson/bin"
      "/run/current-system/sw/bin"
    ];

    home.shellAliases = {
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

    programs.carapace = {
      enable = true;
      enableBashIntegration = true;
    };

    programs.starship = {
      enable = true;
      enableBashIntegration = true;
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
      initExtra = ''
        if [[ -f /run/agenix/openclaw-env ]]; then
          while IFS= read -r line; do
            case "$line" in
              OPENCLAW_GATEWAY_TOKEN=*)
                export OPENCLAW_GATEWAY_TOKEN="''${line#OPENCLAW_GATEWAY_TOKEN=}"
                break
                ;;
            esac
          done < /run/agenix/openclaw-env
        fi
      '';
    };

    programs.kitty = {
      enable = true;
    };

    programs.git = {
      enable = true;
      settings.user = {
        name = "Simon W. Jackson";
        email = "simon@simonwjackson.io";
      };
    };

    programs.lazygit = {
      enable = true;
      settings = {
        keybinding.files = {
          commitChanges = "C";
          commitChangesWithEditor = "C";
        };
        customCommands = [
          {
            key = "c";
            context = "files";
            description = "Split changes into logical AI commits";
            command = "nix run nixpkgs#bun -- x @mariozechner/pi-coding-agent -p --no-session --tools bash,read,grep,find,ls --model 'claude-haiku-4-5' --thinking off --append-system-prompt 'First determine the candidate change set: if any changes are staged, operate only on the currently staged changes. If nothing is staged, operate on all current working tree changes, including untracked files, but not ignored files. Split the candidate change set into the minimum sensible number of logical commits. You may inspect diffs, stage, unstage, and restage changes, including hunk splitting if needed. Do not edit file contents. Do not pull, push, rebase, amend old commits, or touch ignored files. When finished, output only a concise list of the commits you created as <sha> <subject>.' 'Split the repository changes into logical commits and create them.'";
            loadingText = "🤖 Creating logical commits...";
            output = "none";
          }
        ];
        promptToReturnFromSubprocess = false;
      };
    };
  };
}
