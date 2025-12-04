# Default home-manager configuration for all systems
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  # Enable XDG Base Directory specification
  xdg = {
    enable = true;

    # Explicitly set XDG directories (home-manager sets sensible defaults)
    # These follow the XDG Base Directory specification:
    # https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html

    # User-specific configuration files (~/.config)
    configHome = "${config.home.homeDirectory}/.config";

    # User-specific data files (~/.local/share)
    dataHome = "${config.home.homeDirectory}/.local/share";

    # User-specific state files (~/.local/state)
    stateHome = "${config.home.homeDirectory}/.local/state";

    # User-specific cache files (~/.cache)
    cacheHome = "${config.home.homeDirectory}/.cache";
  };

  programs.yazi = {
    enable = true;

    plugins = {
      ouch = pkgs.yaziPlugins.ouch;
    };

    # Set panel ratios similar to lf (1:2:3)
    settings = {
      manager = {
        ratio = [1 2 3];
        show_hidden = true;
      };
    };

    # Configure keybindings
    keymap = {
      manager = {
        prepend_keymap = [
          {
            on = ["<Esc>"];
            run = "quit";
            desc = "Quit Yazi";
          }
          {
            on = ["Y"];
            run = "copy path";
            desc = "Copy full path";
          }
          {
            on = ["C"];
            run = "plugin ouch";
            desc = "Compress with ouch";
          }
        ];
      };
    };

    theme = {
      manager = {
        cwd = {fg = "#81c8be";};

        hovered = {
          fg = "#303446";
          bg = "#8caaee";
        };
        preview_hovered = {
          fg = "#303446";
          bg = "#c6d0f5";
        };

        find_keyword = {
          fg = "#e5c890";
          italic = true;
        };
        find_position = {
          fg = "#f4b8e4";
          bg = "reset";
          italic = true;
        };

        marker_copied = {
          fg = "#a6d189";
          bg = "#a6d189";
        };
        marker_cut = {
          fg = "#e78284";
          bg = "#e78284";
        };
        marker_marked = {
          fg = "#81c8be";
          bg = "#81c8be";
        };
        marker_selected = {
          fg = "#8caaee";
          bg = "#8caaee";
        };

        tab_active = {
          fg = "#303446";
          bg = "#c6d0f5";
        };
        tab_inactive = {
          fg = "#c6d0f5";
          bg = "#51576d";
        };
        tab_width = 1;

        count_copied = {
          fg = "#303446";
          bg = "#a6d189";
        };
        count_cut = {
          fg = "#303446";
          bg = "#e78284";
        };
        count_selected = {
          fg = "#303446";
          bg = "#8caaee";
        };

        border_symbol = "│";
        border_style = {fg = "#414559";};
      };

      mode = {
        normal_main = {
          fg = "#303446";
          bg = "#8caaee";
          bold = true;
        };
        normal_alt = {
          fg = "#8caaee";
          bg = "#414559";
        };

        select_main = {
          fg = "#303446";
          bg = "#a6d189";
          bold = true;
        };
        select_alt = {
          fg = "#a6d189";
          bg = "#414559";
        };

        unset_main = {
          fg = "#303446";
          bg = "#eebebe";
          bold = true;
        };
        unset_alt = {
          fg = "#eebebe";
          bg = "#414559";
        };
      };

      status = {
        separator_open = "";
        separator_close = "";

        progress_label = {
          fg = "#ffffff";
          bold = true;
        };
        progress_normal = {
          fg = "#8caaee";
          bg = "#51576d";
        };
        progress_error = {
          fg = "#e78284";
          bg = "#51576d";
        };

        perm_type = {fg = "#8caaee";};
        perm_read = {fg = "#e5c890";};
        perm_write = {fg = "#e78284";};
        perm_exec = {fg = "#a6d189";};
        perm_sep = {fg = "#838ba7";};
      };

      input = {
        border = {fg = "#8caaee";};
        title = {};
        value = {};
        selected = {reversed = true;};
      };

      pick = {
        border = {fg = "#8caaee";};
        active = {fg = "#f4b8e4";};
        inactive = {};
      };

      confirm = {
        border = {fg = "#8caaee";};
        title = {fg = "#8caaee";};
        content = {};
        list = {};
        btn_yes = {reversed = true;};
        btn_no = {};
      };

      cmp = {
        border = {fg = "#8caaee";};
      };

      tasks = {
        border = {fg = "#8caaee";};
        title = {};
        hovered = {underline = true;};
      };

      which = {
        mask = {bg = "#414559";};
        cand = {fg = "#81c8be";};
        rest = {fg = "#949cbb";};
        desc = {fg = "#f4b8e4";};
        separator = "  ";
        separator_style = {fg = "#626880";};
      };

      help = {
        on = {fg = "#81c8be";};
        run = {fg = "#f4b8e4";};
        desc = {fg = "#949cbb";};
        hovered = {
          bg = "#626880";
          bold = true;
        };
        footer = {
          fg = "#c6d0f5";
          bg = "#51576d";
        };
      };

      notify = {
        title_info = {fg = "#81c8be";};
        title_warn = {fg = "#e5c890";};
        title_error = {fg = "#e78284";};
      };

      filetype = {
        rules = [
          # Media
          {
            mime = "image/*";
            fg = "#81c8be";
          }
          {
            mime = "{audio,video}/*";
            fg = "#e5c890";
          }

          # Archives
          {
            mime = "application/*zip";
            fg = "#f4b8e4";
          }
          {
            mime = "application/x-{tar,bzip*,7z-compressed,xz,rar}";
            fg = "#f4b8e4";
          }

          # Documents
          {
            mime = "application/{pdf,doc,rtf}";
            fg = "#a6d189";
          }

          # Fallback
          {
            name = "*";
            fg = "#c6d0f5";
          }
          {
            name = "*/";
            fg = "#8caaee";
          }
        ];
      };

      spot = {
        border = {fg = "#8caaee";};
        title = {fg = "#8caaee";};
        tbl_cell = {
          fg = "#8caaee";
          reversed = true;
        };
        tbl_col = {bold = true;};
      };
    };
  };

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  programs.lazygit = {
    enable = true;
    settings = {
      gui = {
        tabWidth = 2;
        skipNoStagedFilesWarning = true;
        sidePanelWidth = 0.381;
        expandFocusedSidePanel = true;
        expandedSidePanelWeight = 5;
        timeFormat = "Jan 02, 06";
        shortTimeFormat = "3:04pm";
        theme = {
          activeBorderColor = [
            "#ca9ee6"
            "bold"
          ];
          inactiveBorderColor = [
            "#626880"
          ];
          searchingActiveBorderColor = [
            "#ef9f76"
            "bold"
          ];
          optionsTextColor = [
            "#ca9ee6"
          ];
          selectedLineBgColor = [
            "#51576d"
          ];
          inactiveViewSelectedLineBgColor = [
            "#414559"
          ];
          cherryPickedCommitFgColor = [
            "#ea999c"
          ];
          cherryPickedCommitBgColor = [
            "#eebebe"
          ];
          markedBaseCommitFgColor = [
            "#ca9ee6"
          ];
          markedBaseCommitBgColor = [
            "#ef9f76"
          ];
          unstagedChangesColor = [
            "#e78284"
          ];
          defaultFgColor = [
            "#c6d0f5"
          ];
        };
        showListFooter = false;
        showRandomTip = false;
        showCommandLog = false;
        showBottomLine = true;
        showPanelJumps = false;
        nerdFontsVersion = "3";
        showFileIcons = true;
        spinner = {
          rate = 50;
          frames = [
            "⠋"
            "⠙"
            "⠹"
            "⠸"
            "⠼"
            "⠴"
            "⠦"
            "⠧"
            "⠇"
            "⠏"
          ];
        };
      };
      git = {
        pagers = [
          {
            colorArg = "always";
            pager = "BAT_THEME=\"Catppuccin Frappe\" nix run nixpkgs#delta -- --paging=never";
            useConfig = false;
          }
        ];
        parseEmoji = true;
      };
      os = {
        edit = "nvr --remote-tab-silent {{filename}}";
        editAtLine = "";
        editAtLineAndWait = "";
        editInTerminal = true;
        openDirInEditor = "nvr --remote-tab-silent {{filename}}";
        editPreset = "";
        open = "nvr --remote-tab-silent {{filename}}";
        copyToClipboardCmd = "wl-copy";
        readFromClipboardCmd = "wl-paste";
        shellFunctionsFile = "";
      };
      keybinding = {
        universal = {
          quit = "q";
          quit-alt1 = "<c-c>";
          return = "<esc>";
          quitWithoutChangingDirectory = "Q";
          togglePanel = "<tab>";
          prevItem = "<up>";
          nextItem = "<down>";
          prevItem-alt = "k";
          nextItem-alt = "j";
          prevPage = ",";
          nextPage = ".";
          scrollLeft = "H";
          scrollRight = "L";
          gotoTop = "<";
          gotoBottom = ">";
          gotoTop-alt = "<home>";
          gotoBottom-alt = "<end>";
          toggleRangeSelect = "v";
          rangeSelectDown = "<s-down>";
          rangeSelectUp = "<s-up>";
          prevBlock = "<left>";
          nextBlock = "<right>";
          prevBlock-alt = "h";
          nextBlock-alt = "l";
          nextBlock-alt2 = "<tab>";
          prevBlock-alt2 = "<backtab>";
          jumpToBlock = [
            "1"
            "2"
            "3"
            "4"
            "5"
          ];
          focusMainView = "0";
          nextMatch = "n";
          prevMatch = "N";
          startSearch = "/";
          optionMenu = "<disabled>";
          optionMenu-alt1 = "?";
          select = "<space>";
          goInto = "<enter>";
          confirm = "<enter>";
          confirmInEditor = "<a-enter>";
          remove = "d";
          new = "n";
          edit = "e";
          openFile = "o";
          scrollUpMain = "<pgup>";
          scrollDownMain = "<pgdown>";
          scrollUpMain-alt1 = "K";
          scrollDownMain-alt1 = "J";
          scrollUpMain-alt2 = "<c-u>";
          scrollDownMain-alt2 = "<c-d>";
          executeShellCommand = ":";
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
          diffingMenu-alt = "<c-e>";
          copyToClipboard = "<c-o>";
          openRecentRepos = "<c-r>";
          submitEditorText = "<enter>";
          extrasMenu = "@";
          toggleWhitespaceInDiffView = "<c-w>";
          increaseContextInDiffView = "}";
          decreaseContextInDiffView = "{";
          increaseRenameSimilarityThreshold = ")";
          decreaseRenameSimilarityThreshold = "(";
          openDiffTool = "<c-t>";
        };
        status = {
          checkForUpdate = "u";
          recentRepos = "<enter>";
          allBranchesLogGraph = "a";
        };
        files = {
          commitChanges = "C";
          commitChangesWithoutHook = "w";
          amendLastCommit = "A";
          commitChangesWithEditor = "C";
          findBaseCommitForFixup = "<c-f>";
          confirmDiscard = "x";
          ignoreFile = "i";
          refreshFiles = "r";
          stashAllChanges = "s";
          viewStashOptions = "S";
          toggleStagedAll = "a";
          viewResetOptions = "D";
          fetch = "f";
          toggleTreeView = "`";
          openMergeOptions = "M";
          openStatusFilter = "<c-b>";
          copyFileInfoToClipboard = "y";
          collapseAll = "-";
          expandAll = "=";
        };
        branches = {
          createPullRequest = "o";
          viewPullRequestOptions = "O";
          copyPullRequestURL = "<c-y>";
          checkoutBranchByName = "c";
          forceCheckoutBranch = "F";
          rebaseBranch = "r";
          renameBranch = "R";
          mergeIntoCurrentBranch = "M";
          moveCommitsToNewBranch = "N";
          viewGitFlowOptions = "i";
          fastForward = "f";
          createTag = "T";
          pushTag = "P";
          setUpstream = "u";
          fetchRemote = "f";
          sortOrder = "s";
        };
        worktrees = {
          viewWorktreeOptions = "w";
        };
        commits = {
          squashDown = "s";
          renameCommit = "r";
          renameCommitWithEditor = "R";
          viewResetOptions = "g";
          markCommitAsFixup = "f";
          createFixupCommit = "F";
          squashAboveCommits = "S";
          moveDownCommit = "<c-j>";
          moveUpCommit = "<c-k>";
          amendToCommit = "A";
          resetCommitAuthor = "a";
          pickCommit = "p";
          revertCommit = "t";
          cherryPickCopy = "C";
          pasteCommits = "V";
          markCommitAsBaseForRebase = "B";
          tagCommit = "T";
          checkoutCommit = "<space>";
          resetCherryPick = "<c-R>";
          copyCommitAttributeToClipboard = "y";
          openLogMenu = "<c-l>";
          openInBrowser = "o";
          viewBisectOptions = "b";
          startInteractiveRebase = "i";
          selectCommitsOfCurrentBranch = "*";
        };
        amendAttribute = {
          resetAuthor = "a";
          setAuthor = "A";
          addCoAuthor = "c";
        };
        stash = {
          popStash = "g";
          renameStash = "r";
        };
        commitFiles = {
          checkoutCommitFile = "c";
        };
        main = {
          toggleSelectHunk = "a";
          pickBothHunks = "b";
          editSelectHunk = "E";
        };
        submodules = {
          init = "i";
          update = "u";
          bulkMenu = "b";
        };
        commitMessage = {
          commitMenu = "<c-o>";
        };
      };
      quitOnTopLevelReturn = true;
      disableStartupPopups = true;
      customCommands = [
        {
          key = "c";
          command = "ai-commit -y";
          context = "files";
          description = "AI-generated commit message";
          loadingText = "🤖 Committing...";
          output = "log";
        }
        {
          key = "p";
          context = "files";
          description = "Sync current branch with remote tracking branch";
          command = "git sync {{.CheckedOutBranch.Name}}";
          output = "log";
          loadingText = "🔽 Syncing branch...";
        }
        {
          key = "P";
          context = "files";
          description = "Ship current branch to remote tracking branch";
          command = "git ship --yes {{.CheckedOutBranch.Name}}";
          output = "log";
          loadingText = "🚀 Shipping branch...";
        }
        {
          key = "p";
          context = "commits";
          description = "Sync current branch with remote tracking branch";
          command = "git sync {{.CheckedOutBranch.Name}}";
          output = "log";
          loadingText = "🔽 Syncing branch...";
        }
        {
          key = "P";
          context = "commits";
          description = "Ship current branch to remote tracking branch";
          command = "git ship --yes {{.CheckedOutBranch.Name}}";
          output = "log";
          loadingText = "🚀 Shipping branch...";
        }
        {
          key = "s";
          context = "localBranches";
          description = "Sync selected branch with main";
          command = "git sync {{.SelectedLocalBranch.Name}}";
          output = "log";
          loadingText = "🔽 Syncing branch...";
          prompts = [
            {
              type = "confirm";
              title = "Confirm sync";
              body = "Sync {{.SelectedLocalBranch.Name}} to local branch now?";
            }
          ];
        }
        {
          key = "S";
          context = "localBranches";
          description = "Ship selected branch to {{.SelectedLocalBranch.Name}}";
          prompts = [
            {
              type = "confirm";
              title = "Confirm ship";
              body = "Ship {{.SelectedLocalBranch.Name}} to {{.SelectedLocalBranch.Name}}?";
            }
          ];
          command = "git ship --yes {{.SelectedLocalBranch.Name}}";
          output = "log";
          loadingText = "🚀 Shipping branch...";
        }
      ];
      promptToReturnFromSubprocess = false;
    };
  };

  programs.bat.enable = true;

  # MPV with conditional panscan (only fill screen when fullscreen)
  programs.mpv = {
    enable = true;
    config = {
      panscan = 0;
    };
    profiles = {
      fullscreen-panscan = {
        profile-cond = "fullscreen";
        profile-restore = "copy";
        panscan = 1;
      };
    };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.zsh = {
    enable = true;
    history = {
      size = 10000;
      save = 10000;
      ignoreDups = true;
      ignoreSpace = true;
      expireDuplicatesFirst = true;
      extended = true;
    };

    # Enable auto-suggestions and syntax highlighting if available
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # Enable completion
    enableCompletion = true;

    # Combined init content using mkOrder for proper sequencing
    initContent = let
      bun = lib.getExe pkgs.bun;
      gum = lib.getExe pkgs.gum;
    in
      lib.mkMerge [
        # Before compinit (order 550)
        (lib.mkOrder 550 ''
          # Load API keys from agenix secrets (if available)
          ${
            if (config.mountainous.agenix.enable or false) && ((config.age.secrets or {}) ? credentials_firecrawl-api-key)
            then ''              if [[ -r "${config.age.secrets.credentials_firecrawl-api-key.path}" ]]; then
                          export FIRECRAWL_API_KEY="$(cat ${config.age.secrets.credentials_firecrawl-api-key.path})"
                        fi
            ''
            else ""
          }
          ${
            if (config.mountainous.agenix.enable or false) && ((config.age.secrets or {}) ? email_pushover-token)
            then ''              if [[ -r "${config.age.secrets.email_pushover-token.path}" ]]; then
                          export PUSHOVER_TOKEN="$(cat ${config.age.secrets.email_pushover-token.path})"
                        fi
            ''
            else ""
          }
          ${
            if (config.mountainous.agenix.enable or false) && ((config.age.secrets or {}) ? email_pushover-user)
            then ''              if [[ -r "${config.age.secrets.email_pushover-user.path}" ]]; then
                          export PUSHOVER_USER="$(cat ${config.age.secrets.email_pushover-user.path})"
                        fi
            ''
            else ""
          }
          ${
            if (config.mountainous.agenix.enable or false) && ((config.age.secrets or {}) ? credentials_brave-api-key)
            then ''              if [[ -r "${config.age.secrets.credentials_brave-api-key.path}" ]]; then
                          export BRAVE_API_KEY="$(cat ${config.age.secrets.credentials_brave-api-key.path})"
                        fi
            ''
            else ""
          }
          ${
            if (config.mountainous.agenix.enable or false) && ((config.age.secrets or {}) ? credentials_serper-api-key)
            then ''              if [[ -r "${config.age.secrets.credentials_serper-api-key.path}" ]]; then
                          export SERPER_API_KEY="$(cat ${config.age.secrets.credentials_serper-api-key.path})"
                        fi
            ''
            else ""
          }

          # Enable Ctrl-R for history search (should work by default but ensure it's set)
          bindkey '^R' history-incremental-search-backward

          # Enable up/down arrow keys for history search
          bindkey '^[[A' history-search-backward
          bindkey '^[[B' history-search-forward

          # Enable history expansion
          setopt HIST_VERIFY
          setopt HIST_EXPAND

          # Share history between all sessions
          setopt SHARE_HISTORY
          setopt APPEND_HISTORY
          setopt INC_APPEND_HISTORY

          # Ask function for Claude AI assistance
          ask() {
              ${gum} spin --spinner dot --title "Asking Claude..." -- \
              ${bun} x '@anthropic-ai/claude-code' \
                  --append-system-prompt "You are a technical expert specializing in NixOS, Nix package management, bash scripting, shell programming, and general software development. When answering questions: Always format responses in markdown with proper code blocks using triple backticks and language identifiers. Provide practical, working examples when possible. For Nix/NixOS: Follow best practices with proper module structure and current syntax. For shell scripts: Include error handling and explain command flags. Be concise but thorough, focusing on actionable solutions." \
                  --dangerously-skip-permissions \
                  --verbose \
                  --print \
                  -- "$*" | \
              ${gum} format
          }

          # Kill process by PID, name, or port
          killproc() {
            if [ -z "$1" ]; then
              echo "Usage: kp <pid|process-name|:port>"
              echo "Examples:"
              echo "  kp 1234              # Kill by PID"
              echo "  kp fastify           # Kill by process name"
              echo "  kp :3001             # Kill by port"
              return 1
            fi

            # Check if argument starts with colon (e.g., :3001)
            if [[ "$1" =~ ^:[0-9]+$ ]]; then
              local port="''${1:1}"  # Remove the colon
              local pid=$(ss -tlnp 2>/dev/null | grep ":$port " | sed -n 's/.*pid=\([0-9]*\).*/\1/p' | head -1)
              if [ -z "$pid" ]; then
                echo "No process found on port $port"
                return 1
              fi
              kill -9 $pid && echo "Killed process $pid on port $port"

            # Check if it's a PID (pure number)
            elif [[ "$1" =~ ^[0-9]+$ ]]; then
              if ps -p "$1" > /dev/null 2>&1; then
                kill -9 "$1" && echo "Killed process $1"
              else
                echo "No process found with PID $1"
                return 1
              fi

            # Otherwise treat as process name
            else
              pkill -9 -f "$1" && echo "Killed processes matching '$1'" || {
                echo "No processes found matching '$1'"
                return 1
              }
            fi
          }

          alias kp=killproc
        '')
        # After compinit (default order)
        ''
          # Load just completions
          source <(${pkgs.just}/bin/just --completions zsh)
        ''
      ];
  };

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "simonwjackson";
  home.homeDirectory = "/home/simonwjackson";

  # Shell aliases for both bash and zsh
  home.shellAliases = let
    claudeCodeCmd = "${pkgs.bun}/bin/bun x '@anthropic-ai/claude-code' --dangerously-skip-permissions";
  in {
    tree = "${lib.getExe pkgs.eza} --tree --all --git-ignore";
    ls = "${lib.getExe pkgs.eza}";
    ll = "${lib.getExe pkgs.eza} -l";
    la = "${lib.getExe pkgs.eza} -la";
    ns = let
      nix-search-tv = lib.getExe inputs.nix-search-tv.packages.x86_64-linux.default;
      fzf = lib.getExe pkgs.fzf;
    in "${nix-search-tv} print | ${fzf} --preview '${nix-search-tv} preview {}' --scheme history";
    pretty = "${pkgs.nodePackages.prettier}/bin/prettier";
    claude = claudeCodeCmd;
    vpn = "VPN_NS_CONFIG=/run/agenix/fastest-vpn ${lib.getExe pkgs.vpn-ns}";
  };

  # Basic shell configuration
  programs.bash = {
    enable = true;
    historyControl = ["ignoredups" "erasedups"];
    historyFile = "${config.xdg.stateHome}/bash/history";
    historyFileSize = 10000;
    historySize = 1000;
    historyIgnore = ["ls" "cd" "exit"];
    shellOptions = ["histappend" "checkwinsize" "extglob" "globstar" "checkjobs"];

    # Enable bash completion and other readline features
    bashrcExtra = ''
      # Load API keys from agenix secrets (if available)
      ${
        if config.mountainous.agenix.enable && (config.age.secrets or {}) ? credentials_firecrawl-api-key
        then ''          if [[ -r "${config.age.secrets.credentials_firecrawl-api-key.path}" ]]; then
                  export FIRECRAWL_API_KEY="$(cat ${config.age.secrets.credentials_firecrawl-api-key.path})"
                fi''
        else ""
      }

      # Enable history search with up/down arrows
      bind '"\e[A": history-search-backward'
      bind '"\e[B": history-search-forward'

      # Enable reverse search with Ctrl-R (this should work by default but ensure it's set)
      bind '"\C-r": reverse-search-history'

      # Kill process by PID, name, or port
      killproc() {
        if [ -z "$1" ]; then
          echo "Usage: kp <pid|process-name|:port>"
          echo "Examples:"
          echo "  kp 1234              # Kill by PID"
          echo "  kp fastify           # Kill by process name"
          echo "  kp :3001             # Kill by port"
          return 1
        fi

        # Check if argument starts with colon (e.g., :3001)
        if [[ "$1" =~ ^:[0-9]+$ ]]; then
          local port="''${1:1}"  # Remove the colon
          local pid=$(ss -tlnp 2>/dev/null | grep ":$port " | sed -n 's/.*pid=\([0-9]*\).*/\1/p' | head -1)
          if [ -z "$pid" ]; then
            echo "No process found on port $port"
            return 1
          fi
          kill -9 $pid && echo "Killed process $pid on port $port"

        # Check if it's a PID (pure number)
        elif [[ "$1" =~ ^[0-9]+$ ]]; then
          if ps -p "$1" > /dev/null 2>&1; then
            kill -9 "$1" && echo "Killed process $1"
          else
            echo "No process found with PID $1"
            return 1
          fi

        # Otherwise treat as process name
        else
          pkill -9 -f "$1" && echo "Killed processes matching '$1'" || {
            echo "No processes found matching '$1'"
            return 1
          }
        fi
      }

      alias kp=killproc
    '';
  };

  # Git configuration
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Simon W. Jackson";
        email = "github@simonwjackson.io";
      };
      core.hooksPath = "${config.xdg.configHome}/git/hooks";
      pull.rebase = true;
      pull.ff = "only";
      fetch.prune = true;
      fetch.pruneTags = true;
      alias = {
        ai-commit = "!ai-commit";
        # secret-scanner = "!git-secret-scanner";
        sync = "!git-sync";
        ship = "!git-ship";

        # Worktree management
        wt = "worktree list";
        wta = "!f() { local branch=\"$1\"; local dir=$(echo \"$branch\" | sed 's|/|-|g'); git worktree add \"../$dir\" -b \"$branch\"; }; f";
        wtr = "!f() { local branch=\"$1\"; local dir=$(echo \"$branch\" | sed 's|/|-|g'); git fetch origin \"$branch\" 2>/dev/null || true; git worktree add \"../$dir\" \"origin/$branch\"; }; f";
        wtrm = "!f() { local branch=\"$1\"; local dir=$(echo \"$branch\" | sed 's|/|-|g'); git worktree remove \"../$dir\"; }; f";
        wtp = "worktree prune";

        # Worktree status and info
        wtst = "!git worktree list | awk '{print $1}' | xargs -I {} sh -c 'echo \"=== {} ===\" && git -C {} status -sb'";
        wtb = "!git branch -vv && echo '\n--- Worktrees ---' && git worktree list";

        # Branch management in worktrees
        wtfree = "!comm -23 <(git branch --format='%(refname:short)' | sort) <(git worktree list --porcelain | grep 'branch' | sed 's/branch //' | sort)";
        wtnew = "!comm -23 <(git branch -r | grep -v HEAD | sed 's|origin/||' | sort) <(git worktree list --porcelain | grep 'branch' | sed 's|.*/||' | sort)";

        # Quick operations
        l = "log --oneline --graph --decorate --all -20";

        # Comparison - shows divergence between local and remote tracking branch
        # < means commit is in remote but not local (behind)
        # > means commit is in local but not remote (ahead)
        delta = "!git log --left-right --graph --oneline --decorate @{u}...HEAD 2>/dev/null || echo 'No upstream branch set'";

        # Bare worktree specific
        root = "!pwd | sed 's|/[^/]*$||'";
      };
    };
    ignores = [
      "**/.resession.json"
      "**/.claude/settings.local.json"
    ];
  };

  # SSH configuration
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*" = {
      extraOptions = {
        WarnWeakCrypto = "no-pq-kex";
      };
    };
  };

  # Global git hooks
  # xdg.configFile."git/hooks/pre-push" = {
  #   text = ''
  #     #!/usr/bin/env bash
  #
  #     # Call the standalone git secret scanner
  #     exec git-secret-scanner diverged
  #   '';
  #   executable = true;
  # };

  # Install some basic packages
  home.packages = with pkgs; [
    htop
    btop
    killall
    ripgrep
    fd
    jq
    beads
    ai-commit
    git-sync
    # git-secret-scanner
    brightness-sync
    # firefox - managed by mountainous.firefox module
    chromium
    nodePackages.prettier
  ];

  # Environment variables
  xdg.configFile."walker/config.toml".text = ''
    app_launch_prefix = ""
    terminal_title_flag = ""
    locale = ""
    close_when_open = false
    theme = "default"
    monitor = ""
    hotreload_theme = false
    as_window = false
    timeout = 0
    disable_click_to_close = false
    force_keyboard_focus = false

    [keys]
    accept_typeahead = ["tab"]
    trigger_labels = "lalt"
    next = ["down"]
    prev = ["up"]
    close = ["esc"]
    remove_from_history = ["shift backspace"]
    resume_query = ["ctrl r"]
    toggle_exact_search = ["ctrl m"]

    [keys.activation_modifiers]
    keep_open = "shift"
    alternate = "alt"

    [keys.ai]
    clear_session = ["ctrl x"]
    copy_last_response = ["ctrl c"]
    resume_session = ["ctrl r"]
    run_last_response = ["ctrl e"]

    [events]
    on_activate = ""
    on_selection = ""
    on_exit = ""
    on_launch = ""
    on_query_change = ""

    [list]
    dynamic_sub = true
    keyboard_scroll_style = "emacs"
    max_entries = 50
    show_initial_entries = true
    single_click = true
    visibility_threshold = 20
    placeholder = "No Results"

    [search]
    argument_delimiter = "#"
    placeholder = "Search..."
    delay = 0
    resume_last_query = false

    [activation_mode]
    labels = "jkl;asdf"

    [builtins.applications]
    weight = 5
    name = "applications"
    placeholder = "Applications"
    prioritize_new = true
    hide_actions_with_empty_query = true
    context_aware = true
    refresh = true
    show_sub_when_single = true
    show_icon_when_single = true
    show_generic = true
    history = true

    [builtins.applications.actions]
    enabled = true
    hide_category = false
    hide_without_query = true

    [builtins.bookmarks]
    weight = 5
    placeholder = "Bookmarks"
    name = "bookmarks"
    icon = "bookmark"
    switcher_only = true

    [[builtins.bookmarks.entries]]
    label = "Walker"
    url = "https://github.com/abenz1267/walker"
    keywords = ["walker", "github"]

    [builtins.xdph_picker]
    hidden = true
    weight = 5
    placeholder = "Screen/Window Picker"
    show_sub_when_single = true
    name = "xdphpicker"
    switcher_only = true

    [builtins.ai]
    weight = 5
    placeholder = "AI"
    name = "ai"
    icon = "help-browser"
    switcher_only = true
    show_sub_when_single = true

    [[builtins.ai.anthropic.prompts]]
    model = "claude-3-7-sonnet-20250219"
    temperature = 1
    max_tokens = 1_000
    label = "General Assistant"
    prompt = "You are a helpful general assistant. Keep your answers short and precise."

    [builtins.calc]
    require_number = true
    weight = 5
    name = "calc"
    icon = "accessories-calculator"
    placeholder = "Calculator"
    min_chars = 4

    [builtins.windows]
    weight = 5
    icon = "view-restore"
    name = "windows"
    placeholder = "Windows"
    show_icon_when_single = true

    [builtins.clipboard]
    always_put_new_on_top = true
    exec = "wl-copy"
    weight = 5
    name = "clipboard"
    avoid_line_breaks = true
    placeholder = "Clipboard"
    image_height = 300
    max_entries = 10
    switcher_only = true

    [builtins.commands]
    weight = 5
    icon = "utilities-terminal"
    switcher_only = true
    name = "commands"
    placeholder = "Commands"

    [builtins.custom_commands]
    weight = 5
    icon = "utilities-terminal"
    name = "custom_commands"
    placeholder = "Custom Commands"

    [builtins.emojis]
    exec = "wl-copy"
    weight = 5
    name = "emojis"
    placeholder = "Emojis"
    switcher_only = true
    history = true
    typeahead = true
    show_unqualified = false

    [builtins.symbols]
    after_copy = ""
    weight = 5
    name = "symbols"
    placeholder = "Symbols"
    switcher_only = true
    history = true
    typeahead = true

    [builtins.finder]
    use_fd = false
    fd_flags = "--ignore-vcs --type file"
    weight = 5
    icon = "file"
    name = "finder"
    placeholder = "Finder"
    switcher_only = true
    ignore_gitignore = true
    refresh = true
    concurrency = 8
    show_icon_when_single = true
    preview_images = false

    [builtins.runner]
    eager_loading = true
    weight = 5
    icon = "utilities-terminal"
    name = "runner"
    placeholder = "Runner"
    typeahead = true
    history = true
    generic_entry = false
    refresh = true
    use_fd = false

    [builtins.ssh]
    weight = 5
    icon = "preferences-system-network"
    name = "ssh"
    placeholder = "SSH"
    switcher_only = true
    history = true
    refresh = true

    [builtins.switcher]
    weight = 5
    name = "switcher"
    placeholder = "Switcher"
    prefix = "/"

    [builtins.websearch]
    keep_selection = true
    weight = 5
    icon = "applications-internet"
    name = "websearch"
    placeholder = "Websearch"

    [[builtins.websearch.entries]]
    name = "Google"
    url = "https://www.google.com/search?q=%TERM%"

    [[builtins.websearch.entries]]
    name = "DuckDuckGo"
    url = "https://duckduckgo.com/?q=%TERM%"
    switcher_only = true

    [[builtins.websearch.entries]]
    name = "Ecosia"
    url = "https://www.ecosia.org/search?q=%TERM%"
    switcher_only = true

    [[builtins.websearch.entries]]
    name = "Yandex"
    url = "https://yandex.com/search/?text=%TERM%"
    switcher_only = true

    [builtins.dmenu]
    hidden = true
    weight = 5
    name = "dmenu"
    placeholder = "Dmenu"
    switcher_only = true
    show_icon_when_single = true

    [builtins.translation]
    delay = 1000
    weight = 5
    name = "translation"
    icon = "accessories-dictionary"
    placeholder = "Translation"
    switcher_only = true
    provider = "googlefree"
  '';

  home.sessionVariables = {
    # This is a hack to get around a bug in nixos-option
    # TODO: Remove this when nixos-option is fixed
    # INFO: https://github.com/NixOS/nixpkgs/issues/291051
    NIXOS_OZONE_WL = "1";

    # Allow non-free packages
    NIXPKGS_ALLOW_UNFREE = 1;

    BROWSER = "firefox";
    EDITOR = "nvim";

    # XDG Base Directory specification
    XDG_CONFIG_HOME = "${config.xdg.configHome}";
    XDG_DATA_HOME = "${config.xdg.dataHome}";
    XDG_STATE_HOME = "${config.xdg.stateHome}";
    XDG_CACHE_HOME = "${config.xdg.cacheHome}";

    # VPN namespace config
    VPN_NS_CONFIG = "/run/agenix/fastest-vpn";
  };

  # Enable dark mode support
  mountainous.darkmode = {
    enable = true;
    defaultMode = "dark";
  };

  # Enable agenix secrets management
  mountainous.agenix.enable = true;

  # Enable Claude credentials management
  mountainous.claude = lib.mkIf ((config.mountainous.agenix.enable or false) && ((config.age.secrets or {}) ? credentials_claude-credentials)) {
    enable = true;
    credentialsPath = config.age.secrets.credentials_claude-credentials.path;

    commands = {
      enable = false;
      source = ./claude/commands;
    };

    agents = {
      enable = true;
      source = ./claude/agents;
    };
  };

  # Enable starship prompt
  mountainous.starship.enable = true;

  # Enable atuin with encrypted secrets
  mountainous.atuin =
    lib.mkIf (
      config.mountainous.agenix.enable
      && (config.age.secrets or {}) ? atuin_key
      && (config.age.secrets or {}) ? atuin_session
    ) {
      enable = true;
      key_path = config.age.secrets.atuin_key.path;
      session_path = config.age.secrets.atuin_session.path;
    };

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  home.stateVersion = "24.11";
}
