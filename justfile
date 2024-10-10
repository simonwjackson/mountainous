############################################################################
#
#  Nix commands related to the local machine
#
############################################################################

HOSTS := env_var_or_default('HOSTS', '')
BUILDERS := env_var_or_default('BUILDERS', '')

# Default recipe
default:
    @just --list --unsorted

# Common function to handle shared logic
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

switch *ARGS:
    just _run_nixie_command switch {{ ARGS }}

test *ARGS:
    just _run_nixie_command test {{ ARGS }}

boot *ARGS:
    just _run_nixie_command boot {{ ARGS }}

build *ARGS:
    just _run_nixie_command build {{ ARGS }}

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
