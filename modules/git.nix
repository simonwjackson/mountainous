let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz";
in
{
  imports = [
    (import "${home-manager}/nixos")
  ];

  home-manager.users.simonwjackson = { config, pkgs, ... }: {
    programs.lazygit = {
      enable = true;

      settings = {
        confirmOnQuit = false;
        customCommands = [
          {
            command =
              "[[ ''$TMUX ]] && tmux display-popup -E -e PATH=''$PATH -d \"''$(pwd)\" git gpt || git gpt";
            context = "global";
            description = "GPT Commit";
            key = "G";
            subprocess = true;
          }
          {
            command =
              "[[ ''$TMUX ]] && tmux display-popup -E -e PATH=''$PATH -d \"''$(pwd)\" git trunkit {{index .PromptResponses 0}} || git trunkit {{index .PromptResponses 0}}";
            context = "global";
            description = "Trunkit!";
            key = "t";
            prompts = [{
              title = "Trunkit: Message";
              type = "input";
            }];
          }
        ];
        disableStartupPopups = false;
        git = {
          commit = {
            signOff = false;
            verbose = "default";
          };
          log = {
            allBranchesLogCmd =
              "git log --graph --all --color=always --abbrev-commit --decorate --date=relative  --pretty=medium";
            autoFetch = true;
            autoRefresh = true;
            branchLogCmd =
              "git log --graph --color=always --abbrev-commit --decorate --date=relative --pretty=medium {{branchName}} --";
            diffContextSize = 3;
            disableForcePushing = false;
            order = "topo-order";
            overrideGpg = false;
            parseEmoji = false;
            showGraph = "when-maximised";
            showWholeGraph = false;
            skipHookPrefix = "WIP";
          };
          merging = {
            args = "";
            manualCommit = false;
          };
          paging = {
            colorArg = "always";
            pager = "delta --dark --paging=never";
            useConfig = false;
          };
        };
        gui = {
          commandLogSize = 8;
          commitLength = { show = true; };
          expandFocusedSidePanel = false;
          language = "en";
          mainPanelSplitMode = "flexible";
          mouseEvents = true;
          scrollHeight = 2;
          scrollPastBottom = true;
          showBottomLine = true;
          showCommandLog = true;
          showFileTree = true;
          showIcons = false;
          showListFooter = true;
          showRandomTip = true;
          sidePanelWidth = 0.3333;
          skipStashWarning = false;
          skipUnstageLineWarning = false;
          splitDiff = "auto";
          theme = {
            activeBorderColor = [ "green" "bold" ];
            cherryPickedCommitBgColor = [ "cyan" ];
            cherryPickedCommitFgColor = [ "blue" ];
            defaultFgColor = [ "default" ];
            inactiveBorderColor = [ "white" ];
            optionsTextColor = [ "blue" ];
            selectedLineBgColor = [ "blue" ];
            selectedRangeBgColor = [ "blue" ];
            unstagedChangesColor = [ "red" ];
          };
          timeFormat = "02 Jan 06 15:04 MST";
        };
        keybinding = {
          universal = {
            appendNewline = "<a-enter>";
            branches = {
              checkoutBranchByName = "c";
              createPullRequest = "o";
              fastForward = "f";
              fetchRemote = "f";
              forceCheckoutBranch = "F";
              mergeIntoCurrentBranch = "M";
              pushTag = "P";
              rebaseBranch = "r";
              renameBranch = "R";
              setUpstream = "u";
              viewGitFlowOptions = "i";
              viewPullRequestOptions = "O";
            };
            commitFiles = { checkoutCommitFile = "c"; };
            commits = {
              amendToCommit = "A";
              checkoutCommit = "<space>";
              cherryPickCopy = "c";
              cherryPickCopyRange = "C";
              copyCommitMessageToClipboard = "<c-y>";
              createFixupCommit = "F";
              markCommitAsFixup = "f";
              moveDownCommit = "<c-j>";
              moveUpCommit = "<c-k>";
              openLogMenu = "<c-l>";
              pasteCommits = "v";
              pickCommit = "p";
              renameCommit = "r";
              renameCommitWithEditor = "R";
              resetCherryPick = "<c-R>";
              revertCommit = "t";
              squashAboveCommits = "S";
              squashDown = "s";
              tagCommit = "T";
              viewBisectOptions = "b";
              viewResetOptions = "g";
            };
            confirm = "<enter>";
            "confirm-alt1" = "y";
            copyToClipboard = "<c-o>";
            createPatchOptionsMenu = "<c-p>";
            createRebaseOptionsMenu = "m";
            decreaseContextInDiffView = "{";
            diffingMenu = "W";
            "diffingMenu-alt" = "<c-e>";
            edit = "e";
            executeCustomCommand = ":";
            extrasMenu = "@";
            files = {
              amendLastCommit = "A";
              commitChanges = "C";
              commitChangesWithEditor = "c";
              commitChangesWithoutHook = "w";
              fetch = "f";
              ignoreFile = "i";
              openMergeTool = "M";
              openStatusFilter = "<c-b>";
              refreshFiles = "r";
              stashAllChanges = "s";
              toggleStagedAll = "a";
              toggleTreeView = "`";
              viewResetOptions = "D";
              viewStashOptions = "S";
            };
            filteringMenu = "<c-s>";
            goInto = "<enter>";
            gotoBottom = ">";
            gotoTop = "<";
            increaseContextInDiffView = "}";
            jumpToBlock = [ "1" "2" "3" "4" "5" ];
            main = {
              pickBothHunks = "b";
              toggleDragSelect = "v";
              "toggleDragSelect-alt" = "V";
              toggleSelectHunk = "a";
            };
            new = "n";
            nextBlock = "<right>";
            "nextBlock-alt" = "l";
            nextItem = "<down>";
            "nextItem-alt" = "j";
            nextMatch = "n";
            nextPage = ".";
            nextScreenMode = "+";
            nextTab = "]";
            openFile = "o";
            openRecentRepos = "<c-r>";
            optionMenu = "x";
            "optionMenu-alt1" = "?";
            prevBlock = "<left>";
            "prevBlock-alt" = "h";
            prevItem = "<up>";
            "prevItem-alt" = "k";
            prevMatch = "N";
            prevPage = ",";
            prevScreenMode = "_";
            prevTab = "[";
            pullFiles = "p";
            pushFiles = "P";
            quit = "q";
            "quit-alt1" = "<c-c>";
            quitWithoutChangingDirectory = "Q";
            redo = "<c-z>";
            refresh = "R";
            remove = "d";
            return = "<esc>";
            scrollDownMain = "<pgdown>";
            "scrollDownMain-alt1" = "J";
            "scrollDownMain-alt2" = "<c-d>";
            scrollLeft = "H";
            scrollRight = "L";
            scrollUpMain = "<pgup>";
            "scrollUpMain-alt1" = "K";
            "scrollUpMain-alt2" = "<c-u>";
            select = "<space>";
            stash = {
              popStash = "g";
              renameStash = "r";
            };
            status = {
              checkForUpdate = "u";
              recentRepos = "<enter>";
            };
            submitEditorText = "<enter>";
            submodules = {
              bulkMenu = "b";
              init = "i";
              update = "u";
            };
            togglePanel = "<tab>";
            toggleWhitespaceInDiffView = "<c-w>";
            undo = "z";
          };
        };
        notARepository = "prompt";
        os = {
          editCommand = "";
          editCommandTemplate = "";
          openCommand = "";
        };
        promptToReturnFromSubprocess = false;
        quitOnTopLevelReturn = false;
        refresher = {
          fetchInterval = 60;
          refreshInterval = 10;
        };
        update = {
          days = 14;
          method = "prompt";
        };
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

          color = {
            commit = "auto";
            file = "auto";
            hunk = "auto";
            minus = "auto";
            minus-emph = "auto";
            minus-non-emph = "auto";
            plus = "auto";
            plus-emph = "auto";
            plus-non-emph = "auto";
            whitespace = "auto reverse";
          };
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

        gpt = "!f() { git diff --staged | tr -s '[:space:]' '\n' | head -n 3500 | tr -s '[:space:]' ' ' | sgpt --model gpt-4 --temperature .5 \"Generate a conventional commit from these chages. template: ':emoji: <type>[optional scope]: <description>\n\n[optional body]'. Body is a list. Prepend first line with a gitmoji directly related to the type. ideally, first line is lowercase 50 chars or less\" | tee /dev/tty | (git commit -F - --edit || true); }; f";
        gpt-pr = "!f() { git log main..HEAD --pretty=format:\"%h %s%n%n%b\" | sgpt --model gpt-4 \"Here are my commit messages. Use them to write a summary and a list summarized chages. Each item will be prepended with an emoji and commit  hash. Write informally and imperatively. Format: <summary>\n\n<list>\"; }; f";

        # Squash all unpushed commits with a new message
        squash = "! git reset --soft HEAD~$(git log origin/main..main | grep commit | wc -l | awk '{$1=$1};1') && git commit";
        s = "squash";

        trunkit = "!f() { git stash --include-untracked && git fetch --all && git pull && git stash pop && git add --all && { [ -z \"$1\" ] && git gpt || git commit --message \"$1\"; } && git push; };f";

        # Worktree
        wtl = "worktree list";
        wta = "!f() { git show-ref --verify --quiet refs/heads/$1; local_branch_exists=$?; git ls-remote --exit-code --heads origin $1 > /dev/null 2>&1; remote_branch_exists=$?; if [ $local_branch_exists -eq 0 ]; then git worktree add $1 $1; elif [ $remote_branch_exists -eq 0 ]; then git worktree add -b $1 --track origin/$1 $1; else git worktree add -b $1 $1; fi }; f";
        wtr = "!f() { printf \"Are you sure you want to remove branch (local & remote)? (y/n) \" && read -r REPLY && [ \"$REPLY\" = \"y\" -o \"$REPLY\" = \"Y\" ] && git worktree remove \"$1\" && git worktree prune && git branch -D \"$1\" && git push origin --delete \"$1\"; }; f";
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
  };
}
