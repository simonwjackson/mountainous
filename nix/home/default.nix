# Default home-manager configuration for all systems
{
  pkgs,
  lib,
  ...
}: {
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
        paging = {
          colorArg = "always";
          pager = "BAT_THEME=\"Catppuccin Frappe\" nix run nixpkgs#delta -- --paging=never";
          useConfig = false;
        };
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
          commitChanges = "c";
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
          openMergeTool = "M";
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
          key = "C";
          command = "git-commit-message --accept --quiet";
          context = "files";
          description = "Use AI to generate commit message";
          loadingText = "Generating AI commit message...";
          subprocess = true;
        }
      ];
      promptToReturnFromSubprocess = false;
    };
  };
  programs.bat.enable = true;
  programs.lf = {
    enable = true;

    # Set up the previewer script
    previewer = {
      source = pkgs.writeShellScript "pv.sh" (builtins.readFile ./lf/preview);
    };

    # Basic settings
    settings = {
      icons = true;
      colors = true;
      incsearch = true;
      scrolloff = 10;
      hidden = true;
    };

    # Key bindings
    keybindings = {
      "<enter>" = "open";
      "<esc>" = "quit";
      "q" = "quit";
      "." = "set hidden!";
      "m" = "push :mkdir<space>";
      "t" = "push :touch<space>";
      "<delete>" = "delete";
      "D" = "delete";
      "f" = "fzf_jump";
      "F" = "fzf_search";
      "x" = "extract";
      "J" = "move-parent down";
      "K" = "move-parent up";
      "p" = "paste; clear";
      "~" = "cd ~";
    };

    commands = let
      cp = "${pkgs.coreutils}/bin/cp";
      cat = "${pkgs.coreutils}/bin/cat";
      dirname = "${pkgs.coreutils}/bin/dirname";
      find = "${pkgs.findutils}/bin/find";
      fzf = lib.getExe pkgs.fzf;
      lf = lib.getExe pkgs.lf;
      mkdir = "${pkgs.coreutils}/bin/mkdir";
      mv = "${pkgs.coreutils}/bin/mv";
      ouch = lib.getExe pkgs.ouch;
      printf = "${pkgs.coreutils}/bin/printf";
      rm = "${pkgs.coreutils}/bin/rm";
      rsync = lib.getExe pkgs.rsync;
      sed = lib.getExe pkgs.gnused;
      stdbuf = "${pkgs.coreutils}/bin/stdbuf";
      tar = lib.getExe pkgs.gnutar;
      touch = "${pkgs.coreutils}/bin/touch";
      tr = "${pkgs.coreutils}/bin/tr";
      zip = lib.getExe pkgs.zip;
      zoxide = lib.getExe pkgs.zoxide;
    in {
      touch = ''
        %{{
          IFS=" "
          file="$*"
          ${touch} -- "$file"
          ${lf} -remote "send $id select \"$(${printf} '%s' "$file" | ${sed} 's/\\/\\\\/g;s/"/\\"/g')\""
        }}
      '';
      mkdir = ''
        %{{
          IFS=" "
          file="$*"
          ${mkdir} -p -- "$file"
          ${lf} -remote "send $id cd \"$(${printf} '%s' "$file" | ${sed} 's/\\/\\\\/g;s/"/\\"/g')\""
        }}
      '';
      move-parent = ''
        &{{
          dironly="setlocal \"$(${dirname} -- "$PWD" | ${sed} 's/\\/\\\\/g;s/"/\\"/g')\" dironly"
          ${lf} -remote "send $id :updir; $dironly true; $1; $dironly false; open"
        }}
      '';
      fzf_jump = ''
        ''${{
          res="$(${find} . -maxdepth 1 | ${fzf} --reverse --header="Jump to location")"
          if [ -n "$res" ]; then
            if [ -d "$res" ]; then
                cmd="cd"
            else
                cmd="select"
            fi
            res="$(${printf} '%s' "$res" | ${sed} 's/\\/\\\\/g;s/"/\\"/g')"
            ${lf} -remote "send $id $cmd \"$res\""
          fi
        }}
      '';
      z = ''
        %{{
          result="$(${zoxide} query --exclude "$PWD" "$@" | ${sed} 's/\\/\\\\/g;s/"/\\"/g')"
          ${lf} -remote "send $id cd \"$result\""
        }}
      '';
      zi = ''
        ''${{
          result="$(${zoxide} query -i | ${sed} 's/\\/\\\\/g;s/"/\\"/g')"
          ${lf} -remote "send $id cd \"$result\""
         }}
      '';
      paste = ''
        &{{
          set -- $(${cat} ~/.local/share/lf/files)
          mode="$1"
          shift
          case "$mode" in
              copy)
                  ${rsync} -av --ignore-existing --progress -- "$@" . |
                  ${stdbuf} -i0 -o0 -e0 ${tr} '\r' '\n' |
                  while IFS= read -r line; do
                      line="$(${printf} '%s' "$line" | ${sed} 's/\\/\\\\/g;s/"/\\"/g')"
                      ${lf} -remote "send $id echo \"$line\""
                  done
                  ;;
              move)
                  ${mv} -n -- "$@" .
                  ${lf} -remote "send clear"
                  ;;
          esac
        }}
      '';
      on-init = ''
        :{{
          cmd on-redraw %{{
              if [ "$lf_width" -le 80 ]; then
                  ${lf} -remote "send $id set ratios 1:2"
              elif [ "$lf_width" -le 160 ]; then
                  ${lf} -remote "send $id set ratios 1:2:3"
              else
                  ${lf} -remote "send $id set ratios 1:2:3:5"
              fi
          }}

          on-redraw
        }}
      '';
      on-cd = ''
        &{{
          # Zoxide
          ${zoxide} add "$PWD"

          # Starship
          # fmt="$(STARSHIP_SHELL= starship prompt | sed 's/\\/\\\\/g;s/"/\\"/g')"
          # lf -remote "send $id set promptfmt \"$fmt\""
        }}
      '';
      zip = ''
        ''${{
            set -f
            ${mkdir} $1
            ${cp} -r $fx $1
            ${zip} -r $1.zip $1
            ${rm} -rf $1
        }}
      '';
      tar = ''
        ''${{
            set -f
            ${mkdir} $1
            ${cp} -r $fx $1
            ${tar} czf $1.tar.gz $1
            ${rm} -rf $1
        }}
      '';
      extract = ''
        ''${{
          set -f
          ${ouch} decompress $fx
        }}
      '';
    };
  };

  # Set file sources for lf configuration
  home.file = {
    ".config/lf/colors" = {
      source = ./lf/colors;
    };

    ".config/lf/icons" = {
      source = ./lf/icons;
    };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.zsh = {
    enable = true;
    # Zsh-specific settings would go here
  };

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "simonwjackson";
  home.homeDirectory = "/home/simonwjackson";

  # Shell aliases for both bash and zsh
  home.shellAliases = {
    ll = "ls -l";
    la = "ls -la";
    gcm = "git-commit-message";
    gcma = "git-commit-message --accept";
  };

  # Basic shell configuration
  programs.bash = {
    enable = true;
    # Bash-specific aliases would go here
  };

  # Git configuration
  programs.git = {
    enable = true;
    userName = "NixOS User";
    userEmail = "user@example.com";
    aliases = {
      ai-commit = "!git-commit-message";
    };
  };

  # Install some basic packages
  home.packages = with pkgs; [
    htop
    ripgrep
    fd
    jq
    git-commit-message
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
  };

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  home.stateVersion = "24.11";
}
