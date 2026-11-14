# All differences between the two new gateways belong here.
let
  # Every tool server is a row on the production front door ai
  # (lib/ai-mcp-rows.nix), which admits only the row's callers.
  rows = import ./ai-mcp-rows.nix;
  mailTools = rows.gmail.tools;
  mailPermissions = map (tool: "claw-gmail__${tool}") mailTools;
  sparkyfitnessTools = import ./openclaw-sparkyfitness-tools.nix;
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
      claw-ebay-simon = {
        row = "ebay";
        inherit (rows.ebay) tools;
        codex.defaultToolsApprovalMode = "approve";
      };
      claw-gmail = {
        row = "gmail";
        tools = mailTools;
      };
      claw-calendar = {
        row = "calendar";
        inherit (rows.calendar) tools;
      };
      claw-family-calendar-simon = {
        row = "family-calendar";
        inherit (rows.family-calendar) tools;
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
    ++ (map (tool: "claw-family-calendar-simon__${tool}") rows.family-calendar.tools)
    ++ (map (tool: "sparkyfitness__${tool}") sparkyfitnessTools);
    agentTools = {
      deny = [ "claw-gmail__*" ];
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
        allow = mailPermissions ++ [ "session_status" ];
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
    mailFilingJob = import ./openclaw-mail-filing.nix;
    enableEbaySelling = true;
  };
  laure = {
    name = "laure";
    nodeName = "claw";
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
      claw-family-calendar = {
        row = "family-calendar-laure";
        inherit (rows.family-calendar-laure) tools;
      };
      claw-scryer-laure = {
        row = "scryer-laure";
        inherit (rows.scryer-laure) tools;
      };
    };
    morningBriefPrompt = builtins.readFile ./openclaw-morning-brief-laure.md;
    # Prepared only. Keep disabled: an unsolicited new brief would break continuity.
    enableMorningBrief = false;
    # Her gateway stays up through deploys: a changed container switches in
    # place, so only its changed units restart (modules/openclaw.nix).
    reloadContainerInPlace = true;
  };
}
