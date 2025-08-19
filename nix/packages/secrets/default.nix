{
  lib,
  pkgs,
  writeShellScriptBin,
  symlinkJoin,
  ...
}:
let
  secrets-encrypt = writeShellScriptBin "secrets-encrypt" ''
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if gum is available
    if ! command -v ${pkgs.gum}/bin/gum &> /dev/null; then
        echo "❌ gum is required for interactive encryption"
        exit 1
    fi

    # Find git repository root
    GIT_ROOT=$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null || echo ".")
    SECRETS_DIR="$GIT_ROOT/secrets/agenix"

    if [ ! -d "$SECRETS_DIR" ]; then
        echo "❌ Secrets directory not found: $SECRETS_DIR"
        echo "Make sure you're in a mountainous repository"
        exit 1
    fi

    cd "$SECRETS_DIR"

    echo "🔐 Interactive Secret Encryption"
    echo ""

    # Get secret name
    SECRET_NAME=$(${pkgs.gum}/bin/gum input --placeholder "Enter secret name (e.g., my-api-key)")
    if [[ -z "$SECRET_NAME" ]]; then
        echo "❌ Secret name cannot be empty"
        exit 1
    fi

    # Validate secret name
    if [[ ! "$SECRET_NAME" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        echo "❌ Secret name can only contain letters, numbers, dots, underscores, and hyphens"
        exit 1
    fi

    # Check if secret already exists
    if [[ -f "''${SECRET_NAME}.age" ]]; then
        if ! ${pkgs.gum}/bin/gum confirm "⚠️  Secret ''\'''${SECRET_NAME}.age' already exists. Overwrite?"; then
            echo "❌ Encryption cancelled"
            exit 1
        fi
    fi

    # Get secret value method
    echo ""
    SECRET_METHOD=$(${pkgs.gum}/bin/gum choose "Enter text directly" "Enter multiline text" "Read from file" "Read from environment variable")

    case "$SECRET_METHOD" in
        "Enter text directly")
            SECRET_VALUE=$(${pkgs.gum}/bin/gum input --password --placeholder "Enter secret value")
            ;;
        "Enter multiline text")
            echo "📝 Enter your secret (Ctrl+D to finish):"
            SECRET_VALUE=$(${pkgs.gum}/bin/gum write --placeholder "Enter multiline secret...")
            ;;
        "Read from file")
            SECRET_FILE=$(${pkgs.gum}/bin/gum file .)
            if [[ ! -f "$SECRET_FILE" ]]; then
                echo "❌ File not found: $SECRET_FILE"
                exit 1
            fi
            SECRET_VALUE=$(cat "$SECRET_FILE")
            ;;
        "Read from environment variable")
            ENV_VAR=$(${pkgs.gum}/bin/gum input --placeholder "Enter environment variable name")
            SECRET_VALUE="''${!ENV_VAR:-}"
            if [[ -z "$SECRET_VALUE" ]]; then
                echo "❌ Environment variable '$ENV_VAR' is empty or not set"
                exit 1
            fi
            ;;
    esac

    if [[ -z "$SECRET_VALUE" ]]; then
        echo "❌ Secret value cannot be empty"
        exit 1
    fi

    # Get available hosts
    AVAILABLE_HOSTS=($(ls ../keys/hosts/*.pub | xargs -I {} basename {} | sed 's/_ssh_host_rsa_key\.pub$//' | sed -E 's/^(aarch64-darwin_|aarch64-linux_|x86_64-linux_)//'))
    AVAILABLE_HOSTS_STR=$(printf "%s\n" "''${AVAILABLE_HOSTS[@]}")

    # Host selection
    echo ""
    echo "🖥️  Select which systems should have access:"
    HOST_CHOICE=$(${pkgs.gum}/bin/gum choose "All systems" "Select specific systems" "Current system only")

    case "$HOST_CHOICE" in
        "All systems")
            SELECTED_HOSTS=("''${AVAILABLE_HOSTS[@]}")
            ;;
        "Select specific systems")
            SELECTED_HOSTS_STR=$(echo "$AVAILABLE_HOSTS_STR" | ${pkgs.gum}/bin/gum choose --multiple)
            readarray -t SELECTED_HOSTS <<< "$SELECTED_HOSTS_STR"
            ;;
        "Current system only")
            CURRENT_HOST=$(hostname)
            if [[ " ''${AVAILABLE_HOSTS[*]} " =~ " ''${CURRENT_HOST} " ]]; then
                SELECTED_HOSTS=("$CURRENT_HOST")
            else
                echo "❌ Current host '$CURRENT_HOST' not found in available hosts"
                exit 1
            fi
            ;;
    esac

    # User access
    echo ""
    INCLUDE_USER=$(${pkgs.gum}/bin/gum confirm "👤 Include main user key?" && echo "yes" || echo "no")

    # Show summary
    echo ""
    echo "📋 Summary:"
    echo "   Secret name: ''${SECRET_NAME}.age"
    echo "   Systems: ''${SELECTED_HOSTS[*]}"
    echo "   Include user: $INCLUDE_USER"
    echo ""

    if ! ${pkgs.gum}/bin/gum confirm "🚀 Proceed with encryption?"; then
        echo "❌ Encryption cancelled"
        exit 1
    fi

    # Update secrets.nix FIRST (required for agenix to know which keys to use)
    echo ""
    echo "📝 Updating secrets.nix..."

    # Build the publicKeys array
    if [[ "$INCLUDE_USER" == "yes" ]]; then
        PUBLICKEYS_STR="users ++ ["
    else
        PUBLICKEYS_STR="["
    fi

    # Add selected hosts
    for host in "''${SELECTED_HOSTS[@]}"; do
        PUBLICKEYS_STR+="$host "
    done
    PUBLICKEYS_STR=$(echo "$PUBLICKEYS_STR" | sed 's/ $//')
    PUBLICKEYS_STR+="]"

    # If all systems selected, use shorthand
    if [[ ''${#SELECTED_HOSTS[@]} -eq ''${#AVAILABLE_HOSTS[@]} ]] && [[ "$INCLUDE_USER" == "yes" ]]; then
        PUBLICKEYS_STR="users ++ systems"
    fi

    # Add entry to secrets.nix (before the closing brace)
    ENTRY="  \"''${SECRET_NAME}.age\".publicKeys = ''${PUBLICKEYS_STR};"

    # Check if entry already exists and replace it, otherwise add it
    if grep -q "\"''${SECRET_NAME}.age\"" secrets.nix; then
        # Replace existing entry
        sed -i "s|.*\"''${SECRET_NAME}.age\".*|''${ENTRY}|" secrets.nix
    else
        # Add new entry before the closing brace
        sed -i "/^}$/i\\''${ENTRY}" secrets.nix
    fi

    # Now create the secret file (after secrets.nix is updated)
    echo ""
    echo "🔐 Encrypting secret..."
    echo "$SECRET_VALUE" | nix run github:ryantm/agenix -- -e "''${SECRET_NAME}.age"

    echo "✅ Secret ''\'''${SECRET_NAME}.age' encrypted successfully!"
    echo ""

    # Auto-commit the changes
    echo "📝 Committing changes to git..."
    ${pkgs.git}/bin/git add "''${SECRET_NAME}.age" secrets.nix
    ${pkgs.git}/bin/git commit -m "secrets: Add ''${SECRET_NAME} secret" -m "Generated with secrets-encrypt tool" || true

    echo ""
    echo "🎯 Next steps:"
    echo "   1. Deploy to systems: just switch <hostname>"
    echo "   2. Access secret at: /run/agenix/''${SECRET_NAME}"
    if [[ "$SECRET_NAME" =~ ^user- ]]; then
        echo "      (or /run/user/1000/agenix/''${SECRET_NAME} for user secrets)"
    fi
  '';

  secrets-rekey = writeShellScriptBin "secrets-rekey" ''
    #!/usr/bin/env bash
    set -euo pipefail

    # Find git repository root
    GIT_ROOT=$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null || echo ".")
    SECRETS_DIR="$GIT_ROOT/secrets/agenix"

    if [ ! -d "$SECRETS_DIR" ]; then
        echo "❌ Secrets directory not found: $SECRETS_DIR"
        echo "Make sure you're in a mountainous repository"
        exit 1
    fi

    cd "$SECRETS_DIR"

    echo "🔄 Re-encrypting all secrets..."
    echo ""

    if command -v ${pkgs.gum}/bin/gum &> /dev/null; then
        if ! ${pkgs.gum}/bin/gum confirm "This will re-encrypt all secrets with current keys. Continue?"; then
            echo "❌ Re-encryption cancelled"
            exit 1
        fi
    else
        echo "⚠️  This will re-encrypt all secrets with current keys."
        read -p "Continue? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "❌ Re-encryption cancelled"
            exit 1
        fi
    fi

    nix run github:ryantm/agenix -- --rekey

    echo "✅ All secrets re-encrypted successfully!"
  '';
  # Create a wrapper script that can call either command
  secrets-wrapper = writeShellScriptBin "secrets" ''
    #!/usr/bin/env bash
    
    if [ $# -eq 0 ]; then
        echo "Usage: secrets <command>"
        echo ""
        echo "Available commands:"
        echo "  encrypt    - Interactively encrypt a new secret"
        echo "  rekey      - Re-encrypt all secrets with current keys"
        exit 1
    fi
    
    case "$1" in
        encrypt)
            shift
            exec ${secrets-encrypt}/bin/secrets-encrypt "$@"
            ;;
        rekey)
            shift
            exec ${secrets-rekey}/bin/secrets-rekey "$@"
            ;;
        *)
            echo "Unknown command: $1"
            echo "Use 'secrets encrypt' or 'secrets rekey'"
            exit 1
            ;;
    esac
  '';
in
symlinkJoin {
  name = "secrets";
  paths = [ secrets-wrapper secrets-encrypt secrets-rekey ];
  meta = with lib; {
    description = "Secret management tools for agenix";
    longDescription = ''
      Provides commands for managing agenix secrets:
      - secrets encrypt: Interactive tool to encrypt new secrets
      - secrets rekey: Re-encrypt all secrets with current keys
      
      Both tools work with the mountainous repository structure and
      automatically handle git operations.
    '';
    mainProgram = "secrets";
    platforms = platforms.unix;
    license = licenses.mit;
  };
}