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
        confirmOnQuit = false; # determines whether hitting "esc" will quit the application when there is nothing to cancel/close
        quitOnTopLevelReturn = false;
        disableStartupPopups = false;
        notARepository = "prompt"; # one of= "prompt" | "create" | "skip" | "quit"
        promptToReturnFromSubprocess = false; # display confirmation when subprocess terminates
        customCommands = [
          {
            key = "G";
            description = "GPT Commit";
            command = "[[ $TMUX ]] && tmux display-popup -E -e PATH=$PATH -d \"$(pwd)\" git gpt || git gpt";
            context = "global";
            subprocess = true;
          }
          {
            key = "t";
            description = "Trunkit!";
            command = "[[ $TMUX ]] && tmux display-popup -E -e PATH=$PATH -d \"$(pwd)\" git trunkit {{index .PromptResponses 0}} || git trunkit {{index .PromptResponses 0}}";
            context = "global";
            prompts = [{
              type = "input";
              title = "Trunkit: Message";
            }];
          }
        ];
        gui = {
          # stuff relating to the UI
          scrollHeight = 2; # how many lines you scroll by
          scrollPastBottom = true; # enable scrolling past the bottom
          sidePanelWidth = 0.3333; # number from 0 to 1
          expandFocusedSidePanel = false;
          mainPanelSplitMode = "flexible";
          language = "en";
          timeFormat = "02 Jan 06 15:04 MST"; # https://pkg.go.dev/time#Time.Format
          theme = {
            activeBorderColor = [ "green" "bold" ];
            inactiveBorderColor = [ "white" ];
            optionsTextColor = [ "blue" ];
            selectedLineBgColor = [ "blue" ]; # set to `default` to have no background colour
            selectedRangeBgColor = [ "blue" ];
            cherryPickedCommitBgColor = [ "cyan" ];
            cherryPickedCommitFgColor = [ "blue" ];
            unstagedChangesColor = [ "red" ];
            defaultFgColor = [ "default" ];
          };
          commitLength = {
            show = true;
          };
          mouseEvents = true;
          skipUnstageLineWarning = false;
          skipStashWarning = false;
          showFileTree = true; # for rendering changes files in a tree format
          showListFooter = true; # for seeing the "5 of 20" message in list panels
          showRandomTip = true;
          showBottomLine = true; # for hiding the bottom information line (unless it has important information to tell you)
          showCommandLog = true;
          showIcons = false;
          commandLogSize = 8;
          splitDiff = "auto"; # one of "auto" | "always"
        };

        git = {
          paging = {
            colorArg = "always";
            useConfig = false;
            pager = "delta --dark --paging=never";
          };
          commit = {
            signOff = false;
            verbose = "default"; # one of "default" | "always" | "never"
          };

          merging = {
            # only applicable to unix users
            manualCommit = false;
            # extra args passed to `git merge`, e.g. --no-ff
            args = "";
          };
          log = {
            # one of date-order, author-date-order, topo-order.
            # topo-order makes it easier to read the git log graph, but commits may not
            # appear chronologically. See https://git-scm.com/docs/git-log#_commit_ordering
            order = "topo-order";
            # one of always, never, when-maximised
            # this determines whether the git graph is rendered in the commits panel
            showGraph = "when-maximised";
            # displays the whole git graph by default in the commits panel (equivalent to passing the `--all` argument to `git log`)
            showWholeGraph = false;
            skipHookPrefix = "WIP";
            autoFetch = true;
            autoRefresh = true;
            branchLogCmd = "git log --graph --color=always --abbrev-commit --decorate --date=relative --pretty=medium {{branchName}} --";
            allBranchesLogCmd = "git log --graph --all --color=always --abbrev-commit --decorate --date=relative  --pretty=medium";
            overrideGpg = false; # prevents lazygit from spawning a separate process when using GPG
            disableForcePushing = false;
            parseEmoji = false;
            diffContextSize = 3; # how many lines of context are shown around a change in diffs
          };
        };

        os = {
          editCommand = ""; # see "Configuring File Editing" section
          editCommandTemplate = "";
          openCommand = "";
        };

        refresher = {
          refreshInterval = 10; # File/submodule refresh interval in seconds. Auto-refresh can be disabled via option "git.autoRefresh".
          fetchInterval = 60; # Re-fetch interval in seconds. Auto-fetch can be disabled via option "git.autoFetch".
        };

        update = {
          method = "prompt"; # can be: prompt | background | never
          days = 14; # how often an update is checked for
        };

        keybinding = {
          universal = {
            quit = "q";
            quit-alt1 = "<c-c>"; # alternative/alias of quit
            return = "<esc>"; # return to previous menu, will quit if there"s nowhere to return
            # When set to a printable character, this will work for returning from non-prompt panels
            #return-alt1= null;
            quitWithoutChangingDirectory = "Q";
            togglePanel = "<tab>"; # goto the next panel
            prevItem = "<up>"; # go one line up
            nextItem = "<down>"; # go one line down
            prevItem-alt = "k"; # go one line up
            nextItem-alt = "j"; # go one line down
            prevPage = ","; # go to next page in list
            nextPage = "."; # go to previous page in list
            gotoTop = "<"; # go to top of list
            gotoBottom = ">"; # go to bottom of list
            scrollLeft = "H"; # scroll left within list view
            scrollRight = "L"; # scroll right within list view
            prevBlock = "<left>"; # goto the previous block / panel
            nextBlock = "<right>"; # goto the next block / panel
            prevBlock-alt = "h"; # goto the previous block / panel
            nextBlock-alt = "l"; # goto the next block / panel
            jumpToBlock = [ "1" "2" "3" "4" "5" ]; # goto the Nth block / panel
            nextMatch = "n";
            prevMatch = "N";
            optionMenu = "x"; # show help menu
            optionMenu-alt1 = "?"; # show help menu
            select = "<space>";
            goInto = "<enter>";
            openRecentRepos = "<c-r>";
            confirm = "<enter>";
            confirm-alt1 = "y";
            remove = "d";
            new = "n";
            edit = "e";
            openFile = "o";
            scrollUpMain = "<pgup>"; # main panel scroll up
            scrollDownMain = "<pgdown>"; # main panel scroll down
            scrollUpMain-alt1 = "K"; # main panel scroll up
            scrollDownMain-alt1 = "J"; # main panel scroll down
            scrollUpMain-alt2 = "<c-u>"; # main panel scroll up
            scrollDownMain-alt2 = "<c-d>"; # main panel scroll down
            executeCustomCommand = ":";
            createRebaseOptionsMenu = "m";
            pushFiles = "P";
            pullFiles = "p";
            refresh = "R";
            createPatchOptionsMenu = "<c-p>";
            nextTab = "]";
            prevTab = "[";
            nextScreenMode = "+";
            prevScreenMode = "_";
            undo = "z";
            redo = "<c-z>";
            filteringMenu = "<c-s>";
            diffingMenu = "W";
            diffingMenu-alt = "<c-e>"; # deprecated
            copyToClipboard = "<c-o>";
            submitEditorText = "<enter>";
            appendNewline = "<a-enter>";
            extrasMenu = "@";
            toggleWhitespaceInDiffView = "<c-w>";
            increaseContextInDiffView = "}";
            decreaseContextInDiffView = "{";
            status = {
              checkForUpdate = "u";
              recentRepos = "<enter>";
            };
            files = {
              commitChanges = "C";
              commitChangesWithoutHook = "w"; # commit changes without pre-commit hook
              amendLastCommit = "A";
              commitChangesWithEditor = "c";
              ignoreFile = "i";
              refreshFiles = "r";
              stashAllChanges = "s";
              viewStashOptions = "S";
              toggleStagedAll = "a"; # stage/unstage all
              viewResetOptions = "D";
              fetch = "f";
              toggleTreeView = "`";
              openMergeTool = "M";
              openStatusFilter = "<c-b>";
            };
            branches = {
              createPullRequest = "o";
              viewPullRequestOptions = "O";
              checkoutBranchByName = "c";
              forceCheckoutBranch = "F";
              rebaseBranch = "r";
              renameBranch = "R";
              mergeIntoCurrentBranch = "M";
              viewGitFlowOptions = "i";
              fastForward = "f"; # fast-forward this branch from its upstream
              pushTag = "P";
              setUpstream = "u"; # set as upstream of checked-out branch
              fetchRemote = "f";
            };
            commits = {
              squashDown = "s";
              renameCommit = "r";
              renameCommitWithEditor = "R";
              viewResetOptions = "g";
              markCommitAsFixup = "f";
              createFixupCommit = "F"; # create fixup commit for this commit
              squashAboveCommits = "S";
              moveDownCommit = "<c-j>"; # move commit down one
              moveUpCommit = "<c-k>"; # move commit up one
              amendToCommit = "A";
              pickCommit = "p"; # pick commit (when mid-rebase)
              revertCommit = "t";
              cherryPickCopy = "c";
              cherryPickCopyRange = "C";
              pasteCommits = "v";
              tagCommit = "T";
              checkoutCommit = "<space>";
              resetCherryPick = "<c-R>";
              copyCommitMessageToClipboard = "<c-y>";
              openLogMenu = "<c-l>";
              viewBisectOptions = "b";
            };
            stash = {
              popStash = "g";
              renameStash = "r";
            };
            commitFiles =
              {
                checkoutCommitFile = "c";
              };
            main = {
              toggleDragSelect = "v";
              toggleDragSelect-alt = "V";
              toggleSelectHunk = "a";
              pickBothHunks = "b";
            };
            submodules = {
              init = "i";
              update = "u";
              bulkMenu = "b";
            };
          };
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
