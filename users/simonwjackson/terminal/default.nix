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
      TERMINAL = "kitty";
      EDITOR = "nvim";
      PAGER = "nvimpager";
    };

    shellAliases = {
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
      kvm = "nix-shell -p barrier --run '{ ssh -N -R 24800:localhost:24800 ushiro.lan; } & { barriers -f --no-tray --debug INFO --name fiji --disable-client-cert-checking --disable-crypto -c ~/ushiro.barriers.conf --address :24800; } & wait -n; pkill -P $$;'";
    };
  };

  home.packages = with pkgs; [
    # Terminal Utils
    exa
    btop
    dialog
    nmap
    fd
    nvimpager
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
      changelog = "! git log --pretty=format:'* %h - %s %n%w(76,4,4)%b%n' --abbrev-commit \"$@\" | perl -0 -p -e 's/(^|[^\\\\])([<>])/\\1\\\\\\2/g ; s/(\\s*\\n)+\\*/\\n*/g' #";
      sync = "! git fetch --tags && git rebase --autostash && git push";

      gpt = "!f() { git diff --staged | sgpt --model gpt-4 --temperature .5 \"Generate a conventional commit from these chages. template: ':emoji: <type>[optional scope]: <description>\n\n[optional body]\n\n[optional footer(s)]'. Prepend first line with a gitmoji directly related to the type. ideally, first line is 50 chars or less\" | tee /dev/tty | (git commit -F - --edit || true); }; f";
      gpt-pr = "!f() { git log main..HEAD --pretty=format:\"%h %s%n%n%b\" | sgpt --model gpt-4 \"Here are my commit messages. Use them to write a detailed pull request. include both title and body.\"; }; f";

      # Squash all unpushed commits with a new message
      squash = "! git reset --soft HEAD~$(git log origin/main..main | grep commit | wc -l | awk '{$1=$1};1') && git commit";
      s = "squash";

      trunkit = "!f(){ git stash --include-untracked && git fetch --all && git pull && git stash pop && git add --all && git commit --message \"\${1}\" && git push ; };f";

      # Worktree
      wta = "!f() { git show-ref --verify --quiet refs/heads/$1; local_branch_exists=$?; git ls-remote --exit-code --heads origin $1 > /dev/null 2>&1; remote_branch_exists=$?; if [ $local_branch_exists -eq 0 ]; then git worktree add $1 $1; elif [ $remote_branch_exists -eq 0 ]; then git worktree add -b $1 --track origin/$1 $1; else git worktree add -b $1 $1; fi }; f";
      wtr = "!f(){ git worktree remove \"\${1}\" \"\${1}\"; };f";
      wtc = "!f(){ mkdir $(basename \"\${1}\" .git); cd $(basename \"\${1}\" .git); git clone --bare \"\${1}\" .bare; echo 'gitdir: ./.bare' > .git; git worktree add main main; };f";
    };

    extraConfig = {
      difftool = {
        prompt = false;
      };

      diff = {
        tool = "vimdiff";
      };

      push = {
        default = "current";
      };

      pull = {
        ff = "only";
      };

      init = {
        defaultBranch = "main";
      };
      safe = {
        directory = [
          "/etc/nixos"
          "/home/simonwjackson/nix-config"
        ];
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
