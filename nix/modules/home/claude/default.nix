{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;

  cfg = config.mountainous.claude;
  
  # Utility function
  jq = lib.getExe pkgs.jq;
in {
  options.mountainous.claude = {
    enable = mkEnableOption "Claude credentials management";

    credentialsPath = mkOption {
      type = types.str;
      description = "Path to encrypted Claude credentials file";
    };
    
    filePattern = mkOption {
      type = types.str;
      default = "*.md";
      description = "File pattern to sync (e.g., *.md, *.txt)";
    };

    commands = {
      enable = mkEnableOption "Claude commands management";
      
      source = mkOption {
        type = types.path;
        description = "Source directory containing Claude command files";
      };
    };

    agents = {
      enable = mkEnableOption "Claude agents management";
      
      source = mkOption {
        type = types.path;
        description = "Source directory containing Claude agent files";
      };
    };
  };

  config = lib.mkMerge [
    (mkIf cfg.enable {
      # Manage Claude credentials with token injection from agenix
      home.activation.manageClaude = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run mkdir -p "$HOME/.claude"
        
        # Read the access token from the agenix secret
        TOKEN=$(cat "${cfg.credentialsPath}")
        
        if [[ -f "$HOME/.claude/.credentials.json" ]]; then
          # Update existing file, preserving other fields
          run ${jq} --arg token "$TOKEN" \
            '.claudeAiOauth.accessToken = $token' \
            "$HOME/.claude/.credentials.json" > "$HOME/.claude/.credentials.json.tmp"
          run mv "$HOME/.claude/.credentials.json.tmp" "$HOME/.claude/.credentials.json"
        else
          # Create new file with minimal structure
          run ${jq} -n --arg token "$TOKEN" \
            '{"claudeAiOauth": {"accessToken": $token, "scopes": ["user:inference", "user:profile"], "subscriptionType": "max"}}' \
            > "$HOME/.claude/.credentials.json"
        fi
        
        # Set proper permissions (read/write for owner only)
        run chmod 600 "$HOME/.claude/.credentials.json"
      '';
    })
    
    (mkIf cfg.commands.enable {
      # Manage Claude commands with simple copy
      home.activation.manageClaude-commands = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run mkdir -p "$HOME/.claude/commands"
        
        if [[ -d "${cfg.commands.source}" ]]; then
          run cp -f "${cfg.commands.source}"/${cfg.filePattern} "$HOME/.claude/commands/" 2>/dev/null || true
          run chmod 644 "$HOME/.claude/commands"/* 2>/dev/null || true
        fi
      '';
    })
    
    (mkIf cfg.agents.enable {
      # Manage Claude agents with simple copy
      home.activation.manageClaude-agents = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run mkdir -p "$HOME/.claude/agents"
        
        if [[ -d "${cfg.agents.source}" ]]; then
          run cp -f "${cfg.agents.source}"/${cfg.filePattern} "$HOME/.claude/agents/" 2>/dev/null || true
          run chmod 644 "$HOME/.claude/agents"/* 2>/dev/null || true
        fi
      '';
    })
  ];
}