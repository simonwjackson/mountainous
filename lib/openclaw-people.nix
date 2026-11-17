# All differences between the two new gateways belong here.
let
  # Every tool server is a row on the production front door ai
  # (lib/ai-mcp-rows.nix), which admits only the row's callers.
  rows = import ./ai-mcp-rows.nix;
  mailTools = rows.gmail.tools;
  mailPermissions = map (tool: "claw-gmail__${tool}") mailTools;
  # Keep the restricted reader's seven tools fixed as the shared row grows.
  mailReaderTools = [
    "mail_list"
    "mail_read"
    "mail_not_mine"
    "mail_label"
    "mail_archive"
    "mail_draft"
    "mail_discard_draft"
  ];
  mailReaderPermissions = map (tool: "claw-gmail__${tool}") mailReaderTools;
  sparkyfitnessTools = import ./openclaw-sparkyfitness-tools.nix;
  # openclaw/openclaw#186775 (model-created Apps), #186777 (standalone Apps):
  # app tool-policy checks lose bundle MCP ownership. Remove these exact
  # allowances once fix PR #186790 is in a deployed OpenClaw release.
  # Auto permits reversible, closed-world Pace writes from their annotations.
  # Keep destructive/open-world approval gates; do not bypass server policy.
  paceAppPermissions = [
    "pace__pace_status"
    "pace__pace_overview"
    "pace__pace_goal_set"
    "pace__pace_goal_add"
    "pace__pace_goal_remove"
    "pace__pace_goal_paid"
    "pace__pace_budget_set"
    "pace__pace_budget_remove"
    "pace__pace_category_correct"
    "pace__pace_category_one_off"
    "pace__pace_changes"
    "pace__pace_undo"
    "pace__pace_events"
    "pace__pace_goal_paid_answer"
  ];
in
{
  simon = {
    name = "simon";
    # The tailnet node was claw-simon until 2026-11-14 and was renamed in
    # place (same node ID). The container and its state keep the old name.
    nodeName = "flakey";
    containerName = "claw-simon";
    workspacePath = "/var/lib/openclaw/workspace";
    roleName = "person";
    agentId = "main"; # Preserve stored session keys during the controlled move.
    login = "simon.jackson@gmail.com";
    identity = {
      name = "flakey";
      emoji = "❄️";
    };
    # Each server keeps its old name and reaches its row on the production
    # front door: https://ai.hummingbird-lake.ts.net/mcp/<row>. The row admits
    # this node's stable ID only; this gateway holds no key.
    mcpServers = {
      pace = {
        row = "pace";
        inherit (rows.pace) tools;
        codex.defaultToolsApprovalMode = "auto";
      };
      claw-ebay-simon = {
        row = "ebay";
        inherit (rows.ebay) tools;
        codex.defaultToolsApprovalMode = "approve";
      };
      claw-gmail = {
        row = "gmail";
        tools = mailTools;
      };
      mindwtr = {
        row = "mindwtr";
        inherit (rows.mindwtr) tools;
      };
      claw-calendar = {
        row = "calendar";
        inherit (rows.calendar) tools;
        codex.defaultToolsApprovalMode = "approve";
      };
      claw-scryer-simon = {
        row = "scryer";
        inherit (rows.scryer) tools;
      };
    };
    extraToolPermissions = [
      "show_widget"
    ]
    ++ (map (tool: "claw-ebay-simon__${tool}") rows.ebay.tools)
    ++ mailPermissions
    ++ (map (tool: "mindwtr__${tool}") rows.mindwtr.tools)
    ++ (map (tool: "claw-calendar__${tool}") rows.calendar.tools)
    ++ (map (tool: "sparkyfitness__${tool}") sparkyfitnessTools)
    ++ paceAppPermissions;
    agentTools = {
      # A wildcard deny would also block app-only tools in the card lease.
      # The row rejects all other tools; main denies every reader-only tool.
      deny = mailReaderPermissions ++ [ "claw-gmail__mail_send" ];
      agentToAgent.send = [ "mail" ];
    };
    agentToAgent = {
      enabled = true;
      allow = [
        "main"
        "mail"
      ];
    };
    extraAgents.mail = {
      name = "Mail reader";
      identity.name = "Mail reader";
      workspace = "/var/lib/openclaw/workspace-mail";
      agentDir = "/var/lib/openclaw/agents/mail/agent";
      model.primary = "front-door/claude-opus-5-5";
      skills = [ ];
      tools = {
        allow = mailReaderPermissions ++ [ "session_status" ];
        # Also deny at exec's own boundary, not only at tool discovery.
        exec.mode = "deny";
        agentToAgent.send = [ ];
      };
    };
    extraAgentInstructions.mail = ./openclaw-mail;
    extraMcpServers = [
      {
        # Through the production front door's /mcp/sparkyfitness row. The row
        # admits this node's stable ID only and holds the SparkyFitness key.
        # This gateway holds no key and sends no credential.
        name = "sparkyfitness";
        value = {
          transport = "streamable-http";
          url = "https://ai.hummingbird-lake.ts.net/mcp/sparkyfitness";
          toolFilter.include = sparkyfitnessTools;
        };
      }
      {
        name = "basic-react";
        bundledDemoTool = "get-time";
      }
      {
        name = "budget-allocator";
        bundledDemoTool = "get-budget-data";
      }
    ];
    morningBriefPrompt = builtins.readFile ./openclaw-morning-brief.md;
    enableMorningBrief = true;
    enableWindDown = true;
    enableVoice = true;
    mailFilingJob = import ./openclaw-mail-filing.nix;
    enableEbaySelling = true;
    enablePaceAlerts = true;
    # Canva's remote MCP server with each sender's own Canva sign-in (lib/openclaw-canva.nix).
    enableCanva = true;
    # Like Laure's: a changed container switches in place, so only its changed
    # units restart. A new gateway config still restarts the gateway (its
    # restart trigger); a new Session Share peer restarts only that source.
    reloadContainerInPlace = true;
  };
  laure = {
    name = "laure";
    # The tailnet node was claw until the in-place rename to snowy (same node
    # ID). The container and its state keep the name openclaw.
    nodeName = "snowy";
    containerName = "openclaw";
    workspacePath = "/var/lib/openclaw/workspace-laure";
    roleName = "laure";
    agentId = "laure";
    login = "chancerellelaure@gmail.com";
    identity = {
      name = "Snowy";
      emoji = "❄️";
      theme = "Calm and clear-headed, a bit dry, and quietly on top of things.";
      avatar = "avatars/avatar.png";
    };
    # Her servers keep their names and reach her rows on the production front
    # door; each row admits this node's stable ID only (stage 7).
    mcpServers = {
      pace = {
        row = "pace-laure";
        inherit (rows.pace-laure) tools;
        codex.defaultToolsApprovalMode = "auto";
      };
      claw-family-calendar = {
        row = "family-calendar-laure";
        inherit (rows.family-calendar-laure) tools;
      };
      claw-scryer-laure = {
        row = "scryer-laure";
        inherit (rows.scryer-laure) tools;
      };
    };
    extraToolPermissions = paceAppPermissions;
    morningBriefPrompt = builtins.readFile ./openclaw-morning-brief-laure.md;
    # Prepared only. Keep disabled: an unsolicited new brief would break continuity.
    enableMorningBrief = false;
    # Her gateway stays up through deploys: a changed container switches in
    # place, so only its changed units restart (modules/openclaw.nix).
    reloadContainerInPlace = true;
  };
}
