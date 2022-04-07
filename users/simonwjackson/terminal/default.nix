{ config, pkgs, ... }:

{
  imports = [
    ./development
    ./zsh
  ];

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    sessionVariables = {
      TERM = "tmux-256color";
    };

    shellAliases = {
      cat = "bat";
      sl = "exa";
      ls = "exa";
      l = "exa -l";
      la = "exa -la";
      ip = "ip --color=auto";
      someday = "task add proj:someday";

      h = "fzf-history-widget";
      more = "less";
      ll = "exa --long --header --git ";
      top = "btop";
      paru = "paru --noconfirm";
      lan = "nmap -n -sn 192.18.1.0/24 -oG - | awk '/Up$/{print $2}' | sort -V";
      wgn = "nmap -n -sn 192.18.2.0/24 -oG - | awk '/Up$/{print $2}' | sort -V";
      all_links = "xidel --extract \"//a/resolve-uri(@href, base-uri())\" \"{$1}\" | xclip -selection clipboard";
    };
  };

  home.packages = with pkgs; [
    # Terminal Utils
    exa
    btop
    dialog
    nmap
  ];

  programs.bat = {
    enable = true;

    config = {
      theme = "GitHub";
      italic-text = "always";
    };
  };

  programs.gh = {
    enable = true;

    settings = {
      git_protocol = "ssh";
      prompt = "enabled";
    };
  };

  programs.git = {
    enable = true;
    userName = "Simon W. Jackson";
    userEmail = "hello@simonwjackson.io";

    delta = {
      enable = true;

      options = {
        features = "side-by-side line-numbers decorations";
        whitespace-error-style = "22 reverse";
        side-by-side = false;
      };
    };

    aliases = {
      d = "difftool";
      mt = "mergetool";

      c = "! git commit --message";
      u = "! git add --update";

      # Commit all with message
      commit-all-with-message = "!git add -A && git c --message";
      # Commit all now and sync
      commit-with-sync = "! git uma && git sync";

      # Update the previous commit with new changes
      amend-staged = "commit --amend --no-edit";
      # Update the previous commit with new changes and change the message.
      amend-staged-with-message = "c --amend";
      # Commit all now: Add changed files and commit with the same message.
      amend-all-now = "commit --amend --no-edit -a";

      fzf = "!f() { git-fzf $@ }; f";
      edit-modified = "! git status --porcelain  | awk '{print $2}' | xargs -I '%' echo \"$(git rev-parse --show-toplevel)/%\" | xargs nvim -p";
      em = "edit-modified";

      # Graph log: gives you history of current branch
      l = "log --graph --decorate --oneline";
      # Graph log all: all commits in repo
      la = "log --graph --decorate --oneline --all";
      # Graph log all as shortlist: tag/branch/labelled commits.
      las = "log --graph --decorate --oneline --all --simplify-by-decoration";
      # Graph who and when.
      lw = "log --color --graph --pretty=format:'%C(214)%h%C(reset)%C(196)%d%C(reset) %s %C(35)(%cr)%C(27) <%an>%C(reset)'";
      # Escape < and > for github markdown, (useful for generating changelogs).
      changelog = "! git log --pretty=format:'* %h - %s %n%w(76,4,4)%b%n' --abbrev-commit \"$@\" | perl -0 -p -e 's/(^|[^\\\\])([<>])/\\1\\\\\\2/g ; s/(\\s*\\n)+\\*/\\n\\n*/g' #";
      sync = "! git fetch --tags && git rebase --autostash && git push";

      # Squash all unpushed commits with a new message
      squash = "! git reset --soft HEAD~$(git log origin/main..main | grep commit | wc -l | awk '{$1=$1};1') && git commit";
      s = "squash";
    };

    extraConfig = {
      difftool = {
        prompt = false;
      };

      diff = {
        tool = "vimdiff";
      };

      push = {
        default = "simple";
      };

      pull = {
        ff = "only";
      };

      init = {
        defaultBranch = "main";
      };
    };
    ignores = [
      ".DS_Store"
      "*.pyc"

      # [N]VIM
      "*~"
      "*.swp"
      "*.swo"

      # VIM: Commands :cs, :ctags
      "tags"
      "cscope.*"

      # VIM session
      "Session.vim"

      # VIM: netrw.vim: Network oriented reading, writing, browsing (eg: ftp scp) 
      ".netrwhist"
    ];
  };

  programs.bash.enable = true;

  programs.fzf = {
    enable = true;

    enableZshIntegration = true;
    enableBashIntegration = true;
    defaultCommand = "rg --files --hidden --follow --glob '!.git'";
    tmux.enableShellIntegration = true;
  };

  programs.tmux = {
    enable = true;

    plugins = with pkgs; [
      tmuxPlugins.sensible
      tmuxPlugins.jump
      tmuxPlugins.extrakto
      tmuxPlugins.tmux-fzf
      {
        plugin = tmuxPlugins.resurrect;
        extraConfig = ''
          set -g @resurrect-strategy-nvim 'session'
          set -g @resurrect-save 'a'
          set -g @resurrect-restore 'A'
        '';
      }
      {
        plugin = tmuxPlugins.continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-boot 'on'
          set -g @continuum-save-interval '60' # minutes
        '';
      }
    ];

    extraConfig = builtins.readFile (./tmux/tmux.conf);
  };
}
