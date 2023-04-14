{
  confirmOnQuit = false; # determines whether hitting "esc" will quit the application when there is nothing to cancel/close
  quitOnTopLevelReturn = false;
  disableStartupPopups = false;
  notARepository = "prompt"; # one of= "prompt" | "create" | "skip" | "quit"
  promptToReturnFromSubprocess = false; # display confirmation when subprocess terminates
  customCommands = [
    {
      key = "G";
      description = "GPT Commit";
      command = "git gpt";
      context = "global";
      subprocess = true;
    }
    {
      key = "t";
      description = "Trunkit!";
      command = "git trunkit {{index .PromptResponses 0}}";
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
}

