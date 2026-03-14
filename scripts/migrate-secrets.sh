#!/usr/bin/env bash
# migrate-secrets.sh - Migrate agenix secrets to directory-based structure
#
# This script reorganizes secrets from flat naming to directory-based organization:
# - secrets/system/    -> System-level secrets (root-owned)
# - secrets/hosts/     -> Host-specific secrets
# - secrets/user/      -> User-owned secrets (home-manager)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_OLD="$REPO_ROOT/secrets/agenix"
SECRETS_NEW="$REPO_ROOT/secrets"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Dry run mode
DRY_RUN="${DRY_RUN:-false}"

move_secret() {
    local src="$1"
    local dst="$2"

    if [[ ! -f "$src" ]]; then
        log_warn "Source not found: $src"
        return 1
    fi

    local dst_dir
    dst_dir="$(dirname "$dst")"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  Would move: $src -> $dst"
    else
        mkdir -p "$dst_dir"
        mv "$src" "$dst"
        log_info "Moved: $(basename "$src") -> ${dst#$SECRETS_NEW/}"
    fi
}

main() {
    log_info "Migrating secrets to directory-based structure..."
    log_info "Source: $SECRETS_OLD"
    log_info "Target: $SECRETS_NEW"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warn "DRY RUN MODE - no changes will be made"
    fi

    # Create directory structure
    if [[ "$DRY_RUN" != "true" ]]; then
        mkdir -p "$SECRETS_NEW"/{system/{networking,services,misc},hosts,user/simonwjackson/{credentials,email,cloud,taskserver,atuin,misc}}
    fi

    echo ""
    log_info "=== System Secrets (Networking) ==="
    move_secret "$SECRETS_OLD/fastest-vpn.age" "$SECRETS_NEW/system/networking/fastest-vpn.age"
    move_secret "$SECRETS_OLD/tailscale.age" "$SECRETS_NEW/system/networking/tailscale.age"
    move_secret "$SECRETS_OLD/tailscale-ephemeral.age" "$SECRETS_NEW/system/networking/tailscale-ephemeral.age"
    move_secret "$SECRETS_OLD/tailscale_env.age" "$SECRETS_NEW/system/networking/tailscale_env.age"
    move_secret "$SECRETS_OLD/proton.age" "$SECRETS_NEW/system/networking/proton.age"
    move_secret "$SECRETS_OLD/vrackie-wifi-password.age" "$SECRETS_NEW/system/networking/vrackie-wifi-password.age"

    echo ""
    log_info "=== System Secrets (Services) ==="
    move_secret "$SECRETS_OLD/aria2-rpc-secret.age" "$SECRETS_NEW/system/services/aria2-rpc-secret.age"
    move_secret "$SECRETS_OLD/sabnzbd-api-key.age" "$SECRETS_NEW/system/services/sabnzbd-api-key.age"
    move_secret "$SECRETS_OLD/sabnzbd-nzb-key.age" "$SECRETS_NEW/system/services/sabnzbd-nzb-key.age"
    move_secret "$SECRETS_OLD/newsdemon-user.age" "$SECRETS_NEW/system/services/newsdemon-user.age"
    move_secret "$SECRETS_OLD/newsdemon-pass.age" "$SECRETS_NEW/system/services/newsdemon-pass.age"
    move_secret "$SECRETS_OLD/paperless_ngx_env.age" "$SECRETS_NEW/system/services/paperless_ngx_env.age"
    move_secret "$SECRETS_OLD/searx-env.age" "$SECRETS_NEW/system/services/searx-env.age"
    move_secret "$SECRETS_OLD/slskd_env.age" "$SECRETS_NEW/system/services/slskd_env.age"
    move_secret "$SECRETS_OLD/tandoor_env.age" "$SECRETS_NEW/system/services/tandoor_env.age"
    move_secret "$SECRETS_OLD/zwave-js-secrets.age" "$SECRETS_NEW/system/services/zwave-js-secrets.age"
    move_secret "$SECRETS_OLD/matrix-shared-secret.age" "$SECRETS_NEW/system/services/matrix-shared-secret.age"

    echo ""
    log_info "=== System Secrets (Misc) ==="
    move_secret "$SECRETS_OLD/game-collection-sync.age" "$SECRETS_NEW/system/misc/game-collection-sync.age"
    move_secret "$SECRETS_OLD/deepseek-api-key.age" "$SECRETS_NEW/system/misc/deepseek-api-key.age"

    echo ""
    log_info "=== Host-Specific Secrets (Syncthing) ==="
    # List of hosts with syncthing secrets
    local hosts=(aka bandi fuji haku naka nyu oku onishi sobo tsukuba unzen usu yari zao)

    for host in "${hosts[@]}"; do
        if [[ "$DRY_RUN" != "true" ]]; then
            mkdir -p "$SECRETS_NEW/hosts/$host"
        fi
        move_secret "$SECRETS_OLD/${host}-syncthing-key.age" "$SECRETS_NEW/hosts/$host/syncthing-key.age"
        move_secret "$SECRETS_OLD/${host}-syncthing-cert.age" "$SECRETS_NEW/hosts/$host/syncthing-cert.age"
    done

    echo ""
    log_info "=== User Secrets (Credentials) ==="
    move_secret "$SECRETS_OLD/user-simonwjackson-anthropic.age" "$SECRETS_NEW/user/simonwjackson/credentials/anthropic.age"
    move_secret "$SECRETS_OLD/user-simonwjackson-openai-api-key.age" "$SECRETS_NEW/user/simonwjackson/credentials/openai-api-key.age"
    move_secret "$SECRETS_OLD/user-simonwjackson-gemini-api-key.age" "$SECRETS_NEW/user/simonwjackson/credentials/gemini-api-key.age"
    move_secret "$SECRETS_OLD/user-simonwjackson-firecrawl-api-key.age" "$SECRETS_NEW/user/simonwjackson/credentials/firecrawl-api-key.age"
    move_secret "$SECRETS_OLD/user-simonwjackson-claude-credentials.age" "$SECRETS_NEW/user/simonwjackson/credentials/claude-credentials.age"
    move_secret "$SECRETS_OLD/user-simonwjackson-github-token.age" "$SECRETS_NEW/user/simonwjackson/credentials/github-token.age"
    move_secret "$SECRETS_OLD/user-simonwjackson-github-token-nix.age" "$SECRETS_NEW/user/simonwjackson/credentials/github-token-nix.age"
    move_secret "$SECRETS_OLD/user-simonwjackson-pin.age" "$SECRETS_NEW/user/simonwjackson/credentials/pin.age"
    move_secret "$SECRETS_OLD/user-simonwjackson.age" "$SECRETS_NEW/user/simonwjackson/credentials/master.age"

    echo ""
    log_info "=== User Secrets (Email/Communication) ==="
    move_secret "$SECRETS_OLD/user-simonwjackson-email.age" "$SECRETS_NEW/user/simonwjackson/email/email.age"
    move_secret "$SECRETS_OLD/user-simonwjackson-gmail.age" "$SECRETS_NEW/user/simonwjackson/email/gmail.age"
    move_secret "$SECRETS_OLD/user-simonwjackson-pushover-token.age" "$SECRETS_NEW/user/simonwjackson/email/pushover-token.age"
    move_secret "$SECRETS_OLD/user-simonwjackson-pushover-user.age" "$SECRETS_NEW/user/simonwjackson/email/pushover-user.age"

    echo ""
    log_info "=== User Secrets (Cloud) ==="
    move_secret "$SECRETS_OLD/user-simonwjackson-dropbox-token.age" "$SECRETS_NEW/user/simonwjackson/cloud/dropbox-token.age"
    move_secret "$SECRETS_OLD/user-simonwjackson-instapaper.age" "$SECRETS_NEW/user/simonwjackson/cloud/instapaper.age"

    echo ""
    log_info "=== User Secrets (Taskserver) ==="
    move_secret "$SECRETS_OLD/user-simonwjackson-taskserver-ca.cert.age" "$SECRETS_NEW/user/simonwjackson/taskserver/ca.cert.age"
    move_secret "$SECRETS_OLD/user-simonwjackson-taskserver-private.key.age" "$SECRETS_NEW/user/simonwjackson/taskserver/private.key.age"
    move_secret "$SECRETS_OLD/user-simonwjackson-taskserver-public.cert.age" "$SECRETS_NEW/user/simonwjackson/taskserver/public.cert.age"

    echo ""
    log_info "=== User Secrets (Atuin) ==="
    move_secret "$SECRETS_OLD/atuin_key.age" "$SECRETS_NEW/user/simonwjackson/atuin/key.age"
    move_secret "$SECRETS_OLD/atuin_session.age" "$SECRETS_NEW/user/simonwjackson/atuin/session.age"

    echo ""
    log_info "=== Cleanup ==="

    if [[ "$DRY_RUN" != "true" ]]; then
        # Check if old directory is empty (except secrets.nix)
        local remaining
        remaining=$(find "$SECRETS_OLD" -name "*.age" 2>/dev/null | wc -l)

        if [[ "$remaining" -eq 0 ]]; then
            log_info "All secrets migrated successfully!"
            log_warn "Old secrets.nix can be deleted: $SECRETS_OLD/secrets.nix"
            log_info "Run: rm -rf $SECRETS_OLD"
        else
            log_warn "Some secrets were not migrated. Remaining .age files:"
            find "$SECRETS_OLD" -name "*.age" -exec basename {} \;
        fi
    fi

    echo ""
    log_info "Migration complete!"
    log_info "Next steps:"
    echo "  1. Update NixOS agenix module for new paths"
    echo "  2. Update home-manager agenix module"
    echo "  3. Run 'nix build .#vm-fuji' to test"
    echo "  4. Delete old secrets: rm -rf $SECRETS_OLD"
}

# Parse arguments
case "${1:-}" in
    --dry-run|-n)
        DRY_RUN="true"
        main
        ;;
    --help|-h)
        echo "Usage: $0 [--dry-run|-n] [--help|-h]"
        echo ""
        echo "Migrate agenix secrets to directory-based structure."
        echo ""
        echo "Options:"
        echo "  --dry-run, -n  Show what would be done without making changes"
        echo "  --help, -h     Show this help message"
        ;;
    "")
        main
        ;;
    *)
        log_error "Unknown option: $1"
        exit 1
        ;;
esac
