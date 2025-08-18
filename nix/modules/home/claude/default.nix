{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf;

  cfg = config.mountainous.claude;
in {
  options.mountainous.claude = {
    enable = mkEnableOption "Whether to enable Claude credentials management";

    credentialsPath = mkOption {
      type = lib.types.str;
      description = "Path to encrypted Claude credentials file";
    };
  };

  config = mkIf cfg.enable {
    # Manage Claude credentials with token injection from agenix
    home.activation.manageClaude = lib.hm.dag.entryAfter ["writeBoundary"] ''
      run mkdir -p "$HOME/.claude"
      
      # Read the access token from the agenix secret
      TOKEN=$(cat "${cfg.credentialsPath}")
      
      if [[ -f "$HOME/.claude/.credentials.json" ]]; then
        # Update existing file, preserving other fields
        run ${pkgs.jq}/bin/jq --arg token "$TOKEN" \
          '.claudeAiOauth.accessToken = $token' \
          "$HOME/.claude/.credentials.json" > "$HOME/.claude/.credentials.json.tmp"
        run mv "$HOME/.claude/.credentials.json.tmp" "$HOME/.claude/.credentials.json"
      else
        # Create new file with minimal structure
        run ${pkgs.jq}/bin/jq -n --arg token "$TOKEN" \
          '{"claudeAiOauth": {"accessToken": $token, "scopes": ["user:inference", "user:profile"], "subscriptionType": "max"}}' \
          > "$HOME/.claude/.credentials.json"
      fi
      
      # Set proper permissions (read/write for owner only)
      run chmod 600 "$HOME/.claude/.credentials.json"
    '';
  };
}