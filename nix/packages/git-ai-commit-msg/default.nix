{
  lib,
  pkgs,
  writeShellApplication,
  ...
}:
writeShellApplication {
  name = "git-ai-commit-msg";

  runtimeInputs = with pkgs; [
    bash
    git
    jq
    curl
    bun
  ];

  text = ''
    # Main orchestrator for AI commit message generation
    # Tries Claude first, falls back to Gemini if Claude fails

    # Function to show usage
    show_usage() {
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Generate commit messages using AI based on staged changes."
      echo "Tries Claude first, falls back to Gemini if Claude fails."
      echo ""
      echo "Options:"
      echo "  -y, --yes              Auto-commit without confirmation"
      echo "  -d, --details          Generate detailed commit message with bullet points"
      echo "  -r, --retry COUNT      Number of retry attempts (default: 3)"
      echo "  -s, --style STYLE      Override detected style (angular, imperative)"
      echo "  --log LEVEL            Set logging level (info, debug, trace)"
      echo "  -h, --help             Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0                     Generate commit message with confirmation"
      echo "  $0 -y                  Auto-commit with generated message"
      echo "  $0 -d                  Generate detailed commit message"
      echo "  $0 --style angular     Force Angular-style commit"
      echo "  $0 --log info          Enable info-level logging"
      exit 0
    }

    # Parse command line arguments
    AUTO_COMMIT=false
    LOG_LEVEL=""

    ARGS=()
    for arg in "$@"; do
      case $arg in
      -y | --yes)
        AUTO_COMMIT=true
        ARGS+=("$arg")
        ;;
      -d | --details)
        ARGS+=("$arg")
        ;;
      -r | --retry)
        ARGS+=("$arg")
        ;;
      --retry=*)
        ARGS+=("$arg")
        ;;
      -s | --style)
        ARGS+=("$arg")
        ;;
      --style=*)
        ARGS+=("$arg")
        ;;
      --log)
        # Next arg is the log level, we need to capture both
        ARGS+=("$arg")
        ;;
      --log=*)
        LOG_LEVEL="''${arg#*=}"
        ARGS+=("$arg")
        ;;
      -h | --help)
        show_usage
        ;;
      *)
        ARGS+=("$arg")
        ;;
      esac
    done

    # Helper function for conditional logging
    log_info() {
      if [[ "$LOG_LEVEL" == "info" || "$LOG_LEVEL" == "debug" || "$LOG_LEVEL" == "trace" ]]; then
        echo "$@" >&2
      fi
    }

    log_error() {
      echo "$@" >&2
    }

    # Get staged files and their changes
    STAGED_DIFF=$(git diff --cached --name-status)
    STAGED_CONTENT=$(git diff --cached)

    if [ "$STAGED_DIFF" = "" ]; then
      echo "No staged files found"
      exit 1
    fi

    log_info "📊 Changes to commit:"
    if [[ "$LOG_LEVEL" == "info" || "$LOG_LEVEL" == "debug" || "$LOG_LEVEL" == "trace" ]]; then
      git diff --staged --stat >&2
      echo "" >&2
    fi

    # Try Claude first
    COMMIT_MESSAGE=""
    PROVIDER=""

    log_info "Trying Claude AI..."
    CLAUDE_SCRIPT="${pkgs.writeShellScript "claude-wrapper" (builtins.readFile ./claude.sh)}"

    if COMMIT_MESSAGE=$(echo "$STAGED_CONTENT" | LOG_LEVEL="$LOG_LEVEL" bash "$CLAUDE_SCRIPT" "''${ARGS[@]}"); then
      PROVIDER="Claude"
      log_info "✓ Successfully generated message with Claude"
    else
      log_info "⚠ Claude failed, falling back to Gemini..."

      # Fallback to Gemini
      GEMINI_SCRIPT="${pkgs.writeShellScript "gemini-wrapper" (builtins.readFile ./gemini.sh)}"

      if COMMIT_MESSAGE=$(echo "$STAGED_CONTENT" | LOG_LEVEL="$LOG_LEVEL" bash "$GEMINI_SCRIPT" "''${ARGS[@]}"); then
        PROVIDER="Gemini"
        log_info "✓ Successfully generated message with Gemini"
      else
        log_error "Error: Both Claude and Gemini failed to generate commit message"
        exit 1
      fi
    fi

    # Validate message
    if [ -z "$COMMIT_MESSAGE" ]; then
      log_error "Error: Generated commit message is empty"
      exit 1
    fi

    echo "Generated commit message (via $PROVIDER):"
    echo "$COMMIT_MESSAGE"
    echo ""

    if [[ "$AUTO_COMMIT" == true ]]; then
      git commit -m "$COMMIT_MESSAGE"
      echo "Changes committed successfully!"
    else
      # Ask for confirmation
      read -p "Commit with this message? (y/N): " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        git commit -m "$COMMIT_MESSAGE"
        echo "Changes committed successfully!"
      else
        echo "Commit cancelled."
      fi
    fi
  '';

  meta = with lib; {
    description = "Generate git commit messages using AI (Claude or Gemini) based on staged changes";
    longDescription = ''
      A tool that analyzes staged git changes and generates commit messages using AI.
      It tries Claude (Anthropic) first, and falls back to Google's Gemini AI if Claude fails.

      The tool detects the commit style from recent commits (Angular vs imperative) and generates
      appropriate messages following the repository's conventions.

      Requires agenix secret 'user-simonwjackson-gemini-api-key' to be available for Gemini fallback.
    '';
    mainProgram = "git-ai-commit-msg";
    platforms = platforms.unix;
    license = licenses.mit;
  };
}
