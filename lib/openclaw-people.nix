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
    agentId = "main"; # Preserve stored session keys during the controlled move.
    login = "simon.jackson@gmail.com";
    identity = {
      name = "flakey";
      emoji = "❄️";
    };
    mcpServers = {
      claw-calendar.tools = [ "calendar_busy" ];
      claw-scryer-simon.tools = scryerTools;
    };
    morningBriefPrompt = builtins.readFile ./openclaw-morning-brief.md;
    enableMorningBrief = true;
  };
  laure = {
    name = "laure";
    nodeName = "claw-laure";
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
    # Enable only at the final 22:00 handoff. No duplicate rehearsal brief.
    enableMorningBrief = false;
  };
}
