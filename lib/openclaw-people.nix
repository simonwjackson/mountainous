# All differences between the two new gateways belong here.
let
  scryerTools = [
    "scryer_graphql"
    "scryer_search"
    "scryer_title"
    "scryer_add"
    "scryer_monitor"
  ];
  mailTools = [
    "mail_list"
    "mail_read"
    "mail_not_mine"
    "mail_label"
    "mail_archive"
    "mail_draft"
    "mail_discard_draft"
  ];
  mailPermissions = map (tool: "claw-gmail__${tool}") mailTools;
in
{
  simon = {
    name = "simon";
    nodeName = "claw-simon";
    containerName = "claw-simon";
    workspacePath = "/var/lib/openclaw/workspace";
    roleName = "person";
    agentId = "main"; # Preserve stored session keys during the controlled move.
    login = "simon.jackson@gmail.com";
    identity = {
      name = "flakey";
      emoji = "❄️";
    };
    mcpServers = {
      claw-ebay-simon = {
        tools = import ./openclaw-ebay-tools.nix;
        codex.defaultToolsApprovalMode = "approve";
      };
      claw-gmail.tools = mailTools;
      claw-calendar.tools = [ "calendar_busy" ];
      claw-scryer-simon.tools = scryerTools;
    };
    extraToolPermissions =
      (map (tool: "claw-ebay-simon__${tool}") (import ./openclaw-ebay-tools.nix)) ++ mailPermissions;
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
    mcpServers = {
      claw-family-calendar.tools = [ "family_calendar_events" ];
      claw-scryer-laure.tools = scryerTools;
    };
    morningBriefPrompt = builtins.readFile ./openclaw-morning-brief-laure.md;
    # Prepared only. Keep disabled: an unsolicited new brief would break continuity.
    enableMorningBrief = false;
  };
}
