############################################################################
#
#  Nix commands related to the local machine
#
############################################################################

HOSTS := env_var_or_default('HOSTS', '')
BUILDERS := env_var_or_default('BUILDERS', '')

# Default recipe
[private]
default:
    @just --list --unsorted

# Common function to handle shared logic
[private]
_run_nixie_command ACTION *ARGS:
    #!/usr/bin/env bash
    set -euo pipefail

    # Strip leading and trailing spaces from ARGS
    ARGS_STRIPPED=$(echo "{{ ARGS }}" | xargs)

    # Check if ARGS starts with -a or --all
    if [[ "$ARGS_STRIPPED" =~ ^(-a|--all) ]]; then
        # Remove -a or --all from ARGS
        ARGS_STRIPPED=$(echo "$ARGS_STRIPPED" | sed 's/^-a\s*//; s/^--all\s*//')
        # Set HOSTS to @all
        HOSTS_VALUE="@all"
    else
        HOSTS_VALUE="{{ HOSTS }}"
    fi

    COMMAND="nix run .#nixie -- {{ ACTION }} $ARGS_STRIPPED"

    get_all_hosts() {
        nix flake show --json | nix run nixpkgs#jq -- --raw-output '.nixosConfigurations | keys | join(",")'
    }

    # Check for various "all systems" triggers
    if [ "$HOSTS_VALUE" = "@all" ] || [ "$HOSTS_VALUE" = "*" ]; then
        COMMAND="HOSTS='$(get_all_hosts)' $COMMAND"
    elif [ -n "$HOSTS_VALUE" ]; then
        COMMAND="HOSTS='$HOSTS_VALUE' $COMMAND"
    fi

    if [ -n "{{ BUILDERS }}" ]; then
        COMMAND="BUILDERS='{{ BUILDERS }}' $COMMAND"
    fi

    echo "Executing: $COMMAND"
    eval $COMMAND

# Helper for nixos-rebuild commands (test, switch) with pre/post deploy hooks
[private]
_run_nixie ACTION *ARGS:
    #!/usr/bin/env bash
    set -euo pipefail
    args=({{ ARGS }})

    # Determine target host
    if [ ${#args[@]} -eq 0 ]; then
        TARGET_HOST=$(hostname)
        EXTRA_ARGS=()
    else
        TARGET_HOST="${args[0]}"
        EXTRA_ARGS=("${args[@]:1}")
    fi

    # Pre-deploy sync (only for switch)
    if [ "{{ ACTION }}" = "switch" ]; then
        just _pre_deploy "${TARGET_HOST}"
    fi

    # Run nixie command
    nixie {{ ACTION }} ${TARGET_HOST} "${EXTRA_ARGS[@]}"

    # Post-deploy sync (only for switch)
    if [ "{{ ACTION }}" = "switch" ]; then
        just _post_deploy "${TARGET_HOST}"
    fi

# Pre-switch hook for bidirectional sync of Claude files
[private]
_pre_deploy TARGET_HOST:
    #!/usr/bin/env bash
    set -euo pipefail

    # Skip if deploying to localhost
    if [[ "{{ TARGET_HOST }}" == "$(hostname)" ]]; then
        exit 0
    fi

    echo "🔄 Bidirectional sync with {{ TARGET_HOST }}..."

    # Ensure local directories exist
    mkdir -p ./nix/home/claude/commands
    mkdir -p ./nix/home/claude/agents

    # Ensure remote directories exist
    ssh {{ TARGET_HOST }} "mkdir -p ~/.claude/commands ~/.claude/agents"

    # Bidirectional sync - merge changes from both sides
    echo "  📥 Syncing from remote..."
    rsync -av "{{ TARGET_HOST }}:~/.claude/commands/" ./nix/home/claude/commands/ 2>/dev/null || true
    rsync -av "{{ TARGET_HOST }}:~/.claude/agents/" ./nix/home/claude/agents/ 2>/dev/null || true

    echo "  📤 Syncing to remote..."
    rsync -av ./nix/home/claude/commands/ "{{ TARGET_HOST }}:~/.claude/commands/" 2>/dev/null || true
    rsync -av ./nix/home/claude/agents/ "{{ TARGET_HOST }}:~/.claude/agents/" 2>/dev/null || true

    # Auto-commit any changes pulled from remote
    if ! git diff --quiet nix/home/claude/ 2>/dev/null; then
        echo "  📝 Committing changes from remote..."
        git add nix/home/claude/
        git commit -m "auto: sync claude files from {{ TARGET_HOST }} (pre-deploy)" || true
    fi

    # Future: Add other pre-deployment syncs here

switch *ARGS:
    just _run_nixie switch {{ ARGS }}

test *ARGS:
    just _run_nixie test {{ ARGS }}

boot *ARGS:
    just _run_nixie boot {{ ARGS }}

build *ARGS:
    nix build .#nixosConfigurations.{{ ARGS }}.config.system.build.toplevel --dry-run

# Post-switch hook - no-op (all syncing done in pre-deploy)
[private]
_post_deploy TARGET_HOST:
    #!/usr/bin/env bash
    # No operation - bidirectional sync handled in pre-deploy
    :

# Update all flake inputs or specific inputs (e.g., just up INPUT1 INPUT2)
up *ARGS:
    nix flake update {{ ARGS }}

# Show the system profile history
history:
    nix profile history --profile /nix/var/nix/profiles/system

# Open the Nix REPL with the nixpkgs flake
repl:
    nix repl -f flake:nixpkgs

# Remove all system generations older than {{ DAYS }}
clean DAYS='7':
    sudo nix profile wipe-history --profile /nix/var/nix/profiles/system --older-than {{ DAYS }}d
    just garbage-collect

# Garbage collect all unused Nix store entries
garbage-collect HOST='$(hostname)':
    ssh {{ HOST }} sudo nix-collect-garbage --delete-old

alias gc := garbage-collect

# Scaffold a new system and home configuration
scaffold *ARGS:
    nix run .#scaffold -- {{ ARGS }}

# Deploy a new system and home configuration
deploy *ARGS:
    nix run .#deploy -- {{ ARGS }}

# Format all Nix files in the repository
format:
    nix fmt .

# Interactively encrypt a new secret
encrypt:
    #!/usr/bin/env bash
    set -euo pipefail

    # Check if gum is available
    if ! command -v gum &> /dev/null; then
        echo "❌ gum is required for interactive encryption"
        echo "Make sure you're in the project directory with direnv loaded"
        echo "Run: direnv allow (if not already done)"
        exit 1
    fi

    # Use agenix from flake
    AGENIX="nix run github:ryantm/agenix --"

    cd secrets/agenix

    echo "🔐 Interactive Secret Encryption"
    echo ""

    # Get secret name
    SECRET_NAME=$(gum input --placeholder "Enter secret name (e.g., my-api-key)")
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
    if [[ -f "${SECRET_NAME}.age" ]]; then
        if ! gum confirm "⚠️  Secret '${SECRET_NAME}.age' already exists. Overwrite?"; then
            echo "❌ Encryption cancelled"
            exit 1
        fi
    fi

    # Get secret value method
    echo ""
    SECRET_METHOD=$(gum choose "Enter text directly" "Enter multiline text" "Read from file" "Read from environment variable")

    case "$SECRET_METHOD" in
        "Enter text directly")
            SECRET_VALUE=$(gum input --password --placeholder "Enter secret value")
            ;;
        "Enter multiline text")
            echo "📝 Enter your secret (Ctrl+D to finish):"
            SECRET_VALUE=$(gum write --placeholder "Enter multiline secret...")
            ;;
        "Read from file")
            SECRET_FILE=$(gum file .)
            if [[ ! -f "$SECRET_FILE" ]]; then
                echo "❌ File not found: $SECRET_FILE"
                exit 1
            fi
            SECRET_VALUE=$(cat "$SECRET_FILE")
            ;;
        "Read from environment variable")
            ENV_VAR=$(gum input --placeholder "Enter environment variable name")
            SECRET_VALUE="${!ENV_VAR:-}"
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
    AVAILABLE_HOSTS_STR=$(printf "%s\n" "${AVAILABLE_HOSTS[@]}")

    # Host selection
    echo ""
    echo "🖥️  Select which systems should have access:"
    HOST_CHOICE=$(gum choose "All systems" "Select specific systems" "Current system only")

    case "$HOST_CHOICE" in
        "All systems")
            SELECTED_HOSTS=("${AVAILABLE_HOSTS[@]}")
            ;;
        "Select specific systems")
            SELECTED_HOSTS_STR=$(echo "$AVAILABLE_HOSTS_STR" | gum choose --multiple)
            readarray -t SELECTED_HOSTS <<< "$SELECTED_HOSTS_STR"
            ;;
        "Current system only")
            CURRENT_HOST=$(hostname)
            if [[ " ${AVAILABLE_HOSTS[*]} " =~ " ${CURRENT_HOST} " ]]; then
                SELECTED_HOSTS=("$CURRENT_HOST")
            else
                echo "❌ Current host '$CURRENT_HOST' not found in available hosts"
                exit 1
            fi
            ;;
    esac

    # User access
    echo ""
    INCLUDE_USER=$(gum confirm "👤 Include main user key?" && echo "yes" || echo "no")

    # Show summary
    echo ""
    echo "📋 Summary:"
    echo "   Secret name: ${SECRET_NAME}.age"
    echo "   Systems: ${SELECTED_HOSTS[*]}"
    echo "   Include user: $INCLUDE_USER"
    echo ""

    if ! gum confirm "🚀 Proceed with encryption?"; then
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
    for host in "${SELECTED_HOSTS[@]}"; do
        PUBLICKEYS_STR+="$host "
    done
    PUBLICKEYS_STR=$(echo "$PUBLICKEYS_STR" | sed 's/ $//')
    PUBLICKEYS_STR+="]"

    # If all systems selected, use shorthand
    if [[ ${#SELECTED_HOSTS[@]} -eq ${#AVAILABLE_HOSTS[@]} ]] && [[ "$INCLUDE_USER" == "yes" ]]; then
        PUBLICKEYS_STR="users ++ systems"
    fi

    # Add entry to secrets.nix (before the closing brace)
    ENTRY="  \"${SECRET_NAME}.age\".publicKeys = ${PUBLICKEYS_STR};"

    # Check if entry already exists and replace it, otherwise add it
    if grep -q "\"${SECRET_NAME}.age\"" secrets.nix; then
        # Replace existing entry
        sed -i "s|.*\"${SECRET_NAME}.age\".*|${ENTRY}|" secrets.nix
    else
        # Add new entry before the closing brace
        sed -i "/^}$/i\\${ENTRY}" secrets.nix
    fi

    # Now create the secret file (after secrets.nix is updated)
    echo ""
    echo "🔐 Encrypting secret..."
    echo "$SECRET_VALUE" | $AGENIX -e "${SECRET_NAME}.age"

    echo "✅ Secret '${SECRET_NAME}.age' encrypted successfully!"
    echo ""

    # Auto-commit the changes
    echo "📝 Committing changes to git..."
    git add "${SECRET_NAME}.age" secrets.nix
    git commit -m "secrets: Add ${SECRET_NAME} secret" -m "Generated with Claude Code" -m "Co-Authored-By: Claude <noreply@anthropic.com>"

    echo ""
    echo "🎯 Next steps:"
    echo "   1. Deploy to systems: just switch <hostname>"
    echo "   2. Access secret at: /run/agenix/${SECRET_NAME}"
    if [[ "$SECRET_NAME" =~ ^user- ]]; then
        echo "      (or /run/user/1000/agenix/${SECRET_NAME} for user secrets)"
    fi

# Encrypt a user-specific secret (auto-prefixed with 'user-')
encrypt-user:
    #!/usr/bin/env bash
    set -euo pipefail

    # Check dependencies
    if ! command -v gum &> /dev/null; then
        echo "❌ gum is required. Make sure direnv is loaded: direnv allow"
        exit 1
    fi
    # Use agenix from flake
    AGENIX="nix run github:ryantm/agenix --"

    cd secrets/agenix

    echo "👤 User Secret Encryption"
    echo ""

    # Get secret name (will be prefixed with user-)
    SECRET_SUFFIX=$(gum input --placeholder "Enter secret name (will be prefixed with 'user-')")
    if [[ -z "$SECRET_SUFFIX" ]]; then
        echo "❌ Secret name cannot be empty"
        exit 1
    fi

    SECRET_NAME="user-${SECRET_SUFFIX}"

    # Check if secret already exists
    if [[ -f "${SECRET_NAME}.age" ]]; then
        if ! gum confirm "⚠️  Secret '${SECRET_NAME}.age' already exists. Overwrite?"; then
            echo "❌ Encryption cancelled"
            exit 1
        fi
    fi

    # Get secret value
    SECRET_METHOD=$(gum choose "Enter text directly" "Enter multiline text" "Read from file")

    case "$SECRET_METHOD" in
        "Enter text directly")
            SECRET_VALUE=$(gum input --password --placeholder "Enter secret value")
            ;;
        "Enter multiline text")
            SECRET_VALUE=$(gum write --placeholder "Enter multiline secret...")
            ;;
        "Read from file")
            SECRET_FILE=$(gum file .)
            SECRET_VALUE=$(cat "$SECRET_FILE")
            ;;
    esac

    if [[ -z "$SECRET_VALUE" ]]; then
        echo "❌ Secret value cannot be empty"
        exit 1
    fi

    # User secrets typically go to all systems with user access
    echo ""
    echo "📋 Creating user secret: ${SECRET_NAME}.age"
    echo "   Access: All systems + user key"
    echo ""

    if ! gum confirm "🚀 Proceed with encryption?"; then
        echo "❌ Encryption cancelled"
        exit 1
    fi

    # Create the secret file
    echo "$SECRET_VALUE" | $AGENIX -e "${SECRET_NAME}.age"

    # Add to secrets.nix
    ENTRY="  \"${SECRET_NAME}.age\".publicKeys = users ++ systems;"

    if grep -q "\"${SECRET_NAME}.age\"" secrets.nix; then
        sed -i "s|.*\"${SECRET_NAME}.age\".*|${ENTRY}|" secrets.nix
    else
        sed -i "/^}$/i\\${ENTRY}" secrets.nix
    fi

    echo "✅ User secret '${SECRET_NAME}.age' encrypted successfully!"
    echo ""

    # Auto-commit the changes
    echo "📝 Committing changes to git..."
    git add "${SECRET_NAME}.age" secrets.nix
    git commit -m "secrets: Add user secret ${SECRET_NAME}" -m "Generated with Claude Code" -m "Co-Authored-By: Claude <noreply@anthropic.com>"

# Encrypt a service-specific secret for current host only
encrypt-service:
    #!/usr/bin/env bash
    set -euo pipefail

    # Check dependencies
    if ! command -v gum &> /dev/null; then
        echo "❌ gum is required. Make sure direnv is loaded: direnv allow"
        exit 1
    fi
    # Use agenix from flake
    AGENIX="nix run github:ryantm/agenix --"

    cd secrets/agenix

    echo "🔧 Service Secret Encryption"
    echo ""

    # Get secret name
    SECRET_NAME=$(gum input --placeholder "Enter service secret name (e.g., nginx-htpasswd)")
    if [[ -z "$SECRET_NAME" ]]; then
        echo "❌ Secret name cannot be empty"
        exit 1
    fi

    # Check if secret already exists
    if [[ -f "${SECRET_NAME}.age" ]]; then
        if ! gum confirm "⚠️  Secret '${SECRET_NAME}.age' already exists. Overwrite?"; then
            echo "❌ Encryption cancelled"
            exit 1
        fi
    fi

    # Get secret value
    SECRET_METHOD=$(gum choose "Enter text directly" "Enter multiline text" "Read from file")

    case "$SECRET_METHOD" in
        "Enter text directly")
            SECRET_VALUE=$(gum input --password --placeholder "Enter secret value")
            ;;
        "Enter multiline text")
            SECRET_VALUE=$(gum write --placeholder "Enter multiline secret...")
            ;;
        "Read from file")
            SECRET_FILE=$(gum file .)
            SECRET_VALUE=$(cat "$SECRET_FILE")
            ;;
    esac

    if [[ -z "$SECRET_VALUE" ]]; then
        echo "❌ Secret value cannot be empty"
        exit 1
    fi

    # Host selection for service
    CURRENT_HOST=$(hostname)
    AVAILABLE_HOSTS=($(ls ../keys/hosts/*.pub | xargs -I {} basename {} | sed 's/_ssh_host_rsa_key\.pub$//' | sed -E 's/^(aarch64-darwin_|aarch64-linux_|x86_64-linux_)//'))

    echo ""
    HOST_CHOICE=$(gum choose "Current host only ($CURRENT_HOST)" "All systems" "Select specific systems")

    case "$HOST_CHOICE" in
        "Current host only ($CURRENT_HOST)")
            if [[ " ${AVAILABLE_HOSTS[*]} " =~ " ${CURRENT_HOST} " ]]; then
                PUBLICKEYS_STR="users ++ [$CURRENT_HOST]"
            else
                echo "❌ Current host '$CURRENT_HOST' not found in available hosts"
                exit 1
            fi
            ;;
        "All systems")
            PUBLICKEYS_STR="users ++ systems"
            ;;
        "Select specific systems")
            AVAILABLE_HOSTS_STR=$(printf "%s\n" "${AVAILABLE_HOSTS[@]}")
            SELECTED_HOSTS_STR=$(echo "$AVAILABLE_HOSTS_STR" | gum choose --multiple)
            readarray -t SELECTED_HOSTS <<< "$SELECTED_HOSTS_STR"
            PUBLICKEYS_STR="users ++ ["
            for host in "${SELECTED_HOSTS[@]}"; do
                PUBLICKEYS_STR+="$host "
            done
            PUBLICKEYS_STR=$(echo "$PUBLICKEYS_STR" | sed 's/ $//')
            PUBLICKEYS_STR+="]"
            ;;
    esac

    echo ""
    echo "📋 Creating service secret: ${SECRET_NAME}.age"
    echo "   Access: $PUBLICKEYS_STR"
    echo ""

    if ! gum confirm "🚀 Proceed with encryption?"; then
        echo "❌ Encryption cancelled"
        exit 1
    fi

    # Create the secret file
    echo "$SECRET_VALUE" | $AGENIX -e "${SECRET_NAME}.age"

    # Add to secrets.nix
    ENTRY="  \"${SECRET_NAME}.age\".publicKeys = ${PUBLICKEYS_STR};"

    if grep -q "\"${SECRET_NAME}.age\"" secrets.nix; then
        sed -i "s|.*\"${SECRET_NAME}.age\".*|${ENTRY}|" secrets.nix
    else
        sed -i "/^}$/i\\${ENTRY}" secrets.nix
    fi

    echo "✅ Service secret '${SECRET_NAME}.age' encrypted successfully!"
    echo ""

    # Auto-commit the changes
    echo "📝 Committing changes to git..."
    git add "${SECRET_NAME}.age" secrets.nix
    git commit -m "secrets: Add service secret ${SECRET_NAME}" -m "Generated with Claude Code" -m "Co-Authored-By: Claude <noreply@anthropic.com>"

# Re-encrypt all secrets (useful after adding/removing keys)
rekey:
    #!/usr/bin/env bash
    set -euo pipefail

    cd secrets/agenix

    echo "🔄 Re-encrypting all secrets..."
    echo ""

    # Use agenix from flake
    AGENIX="nix run github:ryantm/agenix --"

    if command -v gum &> /dev/null; then
        if ! gum confirm "This will re-encrypt all secrets with current keys. Continue?"; then
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

    $AGENIX --rekey

    echo "✅ All secrets re-encrypted successfully!"

# Simple secret creation without interactive prompts (for when gum is not available)
add-secret SECRET_NAME SECRET_VALUE *HOSTS:
    #!/usr/bin/env bash
    set -euo pipefail

    SECRET_NAME="{{ SECRET_NAME }}"
    SECRET_VALUE="{{ SECRET_VALUE }}"
    HOSTS=({{ HOSTS }})

    # Use agenix from flake
    AGENIX="nix run github:ryantm/agenix --"

    cd secrets/agenix

    echo "🔐 Adding secret: ${SECRET_NAME}.age"

    # Determine hosts
    if [[ ${#HOSTS[@]} -eq 0 ]]; then
        PUBLICKEYS_STR="users ++ systems"
        echo "   Access: All systems + user"
    else
        PUBLICKEYS_STR="users ++ ["
        for host in "${HOSTS[@]}"; do
            PUBLICKEYS_STR+="$host "
        done
        PUBLICKEYS_STR=$(echo "$PUBLICKEYS_STR" | sed 's/ $//')
        PUBLICKEYS_STR+="]"
        echo "   Access: ${HOSTS[*]} + user"
    fi

    # Add entry to secrets.nix
    ENTRY="  \"${SECRET_NAME}.age\".publicKeys = ${PUBLICKEYS_STR};"

    if grep -q "\"${SECRET_NAME}.age\"" secrets.nix; then
        sed -i "s|.*\"${SECRET_NAME}.age\".*|${ENTRY}|" secrets.nix
    else
        sed -i "/^}$/i\\${ENTRY}" secrets.nix
    fi

    # Create the secret file
    echo "$SECRET_VALUE" | $AGENIX -e "${SECRET_NAME}.age"

    # Auto-commit
    git add "${SECRET_NAME}.age" secrets.nix
    git commit -m "secrets: Add ${SECRET_NAME} secret" -m "Generated with Claude Code" -m "Co-Authored-By: Claude <noreply@anthropic.com>"

    echo "✅ Secret '${SECRET_NAME}.age' created and committed!"
    echo "   Deploy with: just switch <hostname>"
