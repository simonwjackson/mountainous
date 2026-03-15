############################################################################
#
#  Nix commands related to the local machine
#
############################################################################

HOSTS := env_var_or_default('HOSTS', '')
BUILDERS := env_var_or_default('BUILDERS', '')

# Default recipe
[private]
_default:
    @just --list --unsorted

[group('internal')]
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
        COMMAND="NIXIE_BUILDERS='{{ BUILDERS }}' $COMMAND"
    fi

    echo "Executing: $COMMAND"
    eval $COMMAND

[group('internal')]
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
    nix run .#nixie {{ ACTION }} ${TARGET_HOST} "${EXTRA_ARGS[@]}"

    # Post-deploy sync (only for switch)
    if [ "{{ ACTION }}" = "switch" ]; then
        just _post_deploy "${TARGET_HOST}"
    fi

[group('internal')]
[private]
_pre_deploy TARGET_HOST:
    #!/usr/bin/env bash
    # set -euo pipefail
    #
    # # Skip if deploying to localhost
    # Future: add any pre-deployment bidirectional file syncs here.

[group('internal')]
[private]
_post_deploy TARGET_HOST:
    #!/usr/bin/env bash
    # No operation - bidirectional sync handled in pre-deploy
    :

# Deploy configuration changes to systems
[group('deploy')]
switch *ARGS:
    just _run_nixie switch {{ ARGS }}

# Test configuration without applying
[group('deploy')]
test *ARGS:
    just _run_nixie test {{ ARGS }}

# Set configuration for next boot
[group('deploy')]
boot *ARGS:
    just _run_nixie boot {{ ARGS }}

# Build configuration (dry-run)
[group('deploy')]
build *ARGS:
    #!/usr/bin/env bash
    set -euo pipefail

    # Determine target host
    if [ -z "{{ ARGS }}" ]; then
        TARGET_HOST=$(hostname)
    else
        TARGET_HOST="{{ ARGS }}"
    fi

    nix build .#nixosConfigurations.${TARGET_HOST}.config.system.build.toplevel --dry-run

# Deploy a new system and home configuration
[group('deploy')]
deploy *ARGS:
    nix run .#deploy -- {{ ARGS }}

# Update all flake inputs or specific inputs (e.g., just up INPUT1 INPUT2)
[group('maintenance')]
up *ARGS:
    nix flake update {{ ARGS }}

# Show the system profile history
[group('maintenance')]
history:
    nix profile history --profile /nix/var/nix/profiles/system

# Remove all system generations older than {{ DAYS }}
[group('maintenance')]
clean DAYS='7':
    sudo nix profile wipe-history --profile /nix/var/nix/profiles/system --older-than {{ DAYS }}d
    just garbage-collect

# Garbage collect all unused Nix store entries
[group('maintenance')]
garbage-collect HOST='$(hostname)':
    ssh {{ HOST }} sudo nix-collect-garbage --delete-old

alias gc := garbage-collect

# Open the Nix REPL with the nixpkgs flake
[group('development')]
repl:
    nix repl -f flake:nixpkgs

# Scaffold a new system and home configuration
[group('development')]
scaffold *ARGS:
    nix run .#scaffold -- {{ ARGS }}

# Format all Nix files in the repository
[group('development')]
format:
    nix fmt .

# Interactively encrypt a new secret
[group('secrets')]
encrypt:
    nix run .#secrets -- encrypt

# Re-encrypt all secrets for all hosts (agenix-rekey)
[group('secrets')]
rekey:
    nix run .#agenix-rekey.x86_64-linux.rekey -- -a
    mkdir -p secrets/rekeyed && git add secrets/rekeyed/ 2>/dev/null || true

# Generate syncthing identity for a host
[group('syncthing')]
syncthing-keygen HOSTNAME:
    nix run .#syncthing-keygen -- {{ HOSTNAME }}
