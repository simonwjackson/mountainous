# All differences between the two new gateways belong here.
let
  scryerTools = [
    "scryer_graphql"
    "scryer_search"
    "scryer_title"
    "scryer_add"
    "scryer_monitor"
  ];
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
      claw-calendar.tools = [ "calendar_busy" ];
      claw-scryer-simon.tools = scryerTools;
    };
    extraToolPermissions = map (tool: "claw-ebay-simon__${tool}") (import ./openclaw-ebay-tools.nix);
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
