{
  lib,
  pkgs,
  writeShellScriptBin,
  symlinkJoin,
  ...
}: let
  # Base sync script that handles the core logic
  makeSyncScript = {
    name,
    defaultBranch ? "main",
    promptMerge ? false,
    autoMerge ? false,
  }:
    writeShellScriptBin name ''
      set -euo pipefail

      # Parse command line arguments
      BRANCH="${defaultBranch}"
      PROMPT_MERGE="${
        if promptMerge
        then "true"
        else "false"
      }"
      AUTO_MERGE="${
        if autoMerge
        then "true"
        else "false"
      }"

      while [[ $# -gt 0 ]]; do
        case $1 in
          --yes|-y)
            AUTO_MERGE="true"
            shift
            ;;
          *)
            BRANCH="$1"
            shift
            ;;
        esac
      done

      current=$(${pkgs.git}/bin/git branch --show-current)
      current_dir=$PWD

      # Check for uncommitted changes to tracked files
      if [[ -n $(${pkgs.git}/bin/git status --porcelain) ]]; then
        echo "Error: You have uncommitted changes."
        echo "Please stash or commit your changes before syncing:"
        echo ""
        echo "  git stash push -m \"Work in progress\""
        echo ""
        ${pkgs.git}/bin/git status --short
        exit 1
      fi

      # Fetch latest changes
      echo "Fetching latest changes..."
      ${pkgs.git}/bin/git fetch origin

      # Check if we're in a worktree setup
      if ${pkgs.git}/bin/git worktree list &>/dev/null && [[ $(${pkgs.git}/bin/git worktree list | wc -l) -gt 1 ]]; then
        # Worktree setup: find and use the target branch worktree
        main_worktree=$(${pkgs.git}/bin/git worktree list | grep -E "\\b$BRANCH\\b" | awk '{print $1}')
        if [[ -n "$main_worktree" && -d "$main_worktree" ]]; then
          echo "Using worktree setup"

          # Fetch latest branch from origin
          echo "Fetching latest $BRANCH from origin..."
          ${pkgs.git}/bin/git fetch origin "$BRANCH"

          # Rebase current branch onto FETCH_HEAD (which is origin/branch)
          echo "Rebasing $current onto origin/$BRANCH..."
          if ${pkgs.git}/bin/git rebase FETCH_HEAD; then
            echo "Rebase successful!"

            # Handle merge prompt if requested
            if [[ "$PROMPT_MERGE" == "true" ]]; then
              if [[ "$AUTO_MERGE" == "true" ]]; then
                # Auto-merge without prompting
                echo "Pushing $current to origin/$BRANCH..."
                if [[ -n "$main_worktree" && -d "$main_worktree" ]]; then
                  cd "$main_worktree"
                  ${pkgs.git}/bin/git pull origin "$BRANCH"
                  cd "$current_dir"
                  ${pkgs.git}/bin/git push origin "$current":"$BRANCH"
                else
                  ${pkgs.git}/bin/git push origin "$current":"$BRANCH"
                fi
                echo "Successfully merged to $BRANCH!"
              else
                echo ""
                echo -e "\033[1;36m========================================"
                echo -e "MERGE TO REMOTE?"
                echo -e "========================================\033[0m"
                echo -e "\033[1;33mPush local branch '$current' → remote '$BRANCH'\033[0m"
                echo ""
                read -p "Merge? (y/n) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                  echo "Pushing $current to origin/$BRANCH..."
                  if [[ -n "$main_worktree" && -d "$main_worktree" ]]; then
                    cd "$main_worktree"
                    ${pkgs.git}/bin/git pull origin "$BRANCH"
                    cd "$current_dir"
                    ${pkgs.git}/bin/git push origin "$current":"$BRANCH"
                  else
                    ${pkgs.git}/bin/git push origin "$current":"$BRANCH"
                  fi
                  echo "Successfully merged to $BRANCH!"
                fi
              fi
            fi
          else
            echo "Rebase failed! Conflicts detected."
            echo ""
            read -p "Open lazygit to resolve conflicts? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
              ${pkgs.nix}/bin/nix run nixpkgs#lazygit
              echo ""
              echo "After resolving conflicts in lazygit, the rebase should be complete."
            else
              echo "To resolve conflicts manually, run:"
              echo "   nix run nixpkgs#lazygit"
              echo "Or resolve manually and run:"
              echo "   git rebase --continue"
            fi
            exit 1
          fi
        else
          echo "Target branch ($BRANCH) worktree not found!"
          exit 1
        fi
      else
        # Standard git repo: rebase approach
        echo "Using standard git repo approach"

        # Fetch latest branch from origin
        ${pkgs.git}/bin/git fetch origin "$BRANCH"

        echo "Rebasing $current onto origin/$BRANCH..."
        if ${pkgs.git}/bin/git rebase "origin/$BRANCH"; then
          echo "Rebase successful!"

          # Handle merge prompt if requested
          if [[ "$PROMPT_MERGE" == "true" ]]; then
            if [[ "$AUTO_MERGE" == "true" ]]; then
              # Auto-merge without prompting
              echo "Pushing $current to origin/$BRANCH..."
              ${pkgs.git}/bin/git push origin "$current":"$BRANCH"
              echo "Successfully merged to $BRANCH!"
            else
              echo ""
              echo -e "\033[1;36m========================================"
              echo -e "MERGE TO REMOTE?"
              echo -e "========================================\033[0m"
              echo -e "\033[1;33mPush local branch '$current' → remote '$BRANCH'\033[0m"
              echo ""
              read -p "Merge? (y/n) " -n 1 -r
              echo
              if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "Pushing $current to origin/$BRANCH..."
                ${pkgs.git}/bin/git push origin "$current":"$BRANCH"
                echo "Successfully merged to $BRANCH!"
              fi
            fi
          fi
        else
          echo "Rebase failed! Conflicts detected."
          echo ""
          read -p "Open lazygit to resolve conflicts? (y/n) " -n 1 -r
          echo
          if [[ $REPLY =~ ^[Yy]$ ]]; then
            ${pkgs.nix}/bin/nix run nixpkgs#lazygit
            echo ""
            echo "After resolving conflicts in lazygit, the rebase should be complete."
          else
            echo "To resolve conflicts manually, run:"
            echo "   nix run nixpkgs#lazygit"
            echo "Or resolve manually and run:"
            echo "   git rebase --continue"
          fi
          exit 1
        fi
      fi
    '';

  # Create git-sync command (no merge prompt)
  git-sync = makeSyncScript {
    name = "git-sync";
    defaultBranch = "main";
    promptMerge = false;
  };

  # Create git-ship command (with merge prompt, supports --yes)
  git-ship = makeSyncScript {
    name = "git-ship";
    defaultBranch = "main";
    promptMerge = true;
  };
in
  # Combine both commands into a single package
  symlinkJoin {
    name = "git-sync-tools";
    paths = [git-sync git-ship];

    meta = with lib; {
      description = "Git workflow tools for syncing and shipping branches";
      longDescription = ''
        A collection of git workflow tools:

        - git-sync [branch]: Sync (rebase) current branch with target branch (default: main)
        - git-ship [--yes] [branch]: Sync and optionally merge to target branch

        Both commands:
        - Check for uncommitted changes
        - Fetch latest changes from origin
        - Rebase current branch onto target branch
        - Handle both standard git repos and worktree setups
        - Offer to open lazygit on conflicts

        git-ship additionally:
        - Prompts to merge current branch to target branch
        - Supports --yes/-y flag to auto-merge without prompting
      '';
      mainProgram = "git-sync";
      platforms = platforms.unix;
      license = licenses.mit;
    };
  }
