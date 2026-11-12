# Compare the actual generated gateway configurations, not an input template.
# This allowlist names every permitted difference. A new unlisted difference fails.
{ lib, host }:
let
  people = import ../lib/openclaw-people.nix;
  configs = lib.mapAttrs (
    _: person: host.containers.${person.nodeName}.config.services.openclaw-gateway.config
  ) people;
  normalize =
    person: c:
    let
      agent = c.agents.entries.${person.agentId};
    in
    c
    // {
      gateway = (builtins.removeAttrs c.gateway [ "publicOrigin" ]) // {
        auth = c.gateway.auth // {
          trustedProxy = builtins.removeAttrs c.gateway.auth.trustedProxy [ "allowUsers" ];
        };
        roles = c.gateway.roles // {
          definitions.person = builtins.removeAttrs c.gateway.roles.definitions.person [ "agents" ];
        };
        controlUi = builtins.removeAttrs c.gateway.controlUi [ "allowedOrigins" ];
      };
      agents = c.agents // {
        defaults = builtins.removeAttrs c.agents.defaults [
          "systemAgent"
          "sessionStore"
        ];
        entries.person = builtins.removeAttrs agent [
          "identity"
          "agentDir"
        ];
      };
      talk = builtins.removeAttrs c.talk [ "agentId" ];
      mcp = c.mcp // {
        servers = builtins.removeAttrs c.mcp.servers (lib.attrNames person.mcpServers);
        apps = builtins.removeAttrs c.mcp.apps [ "sandboxOrigin" ];
      };
      skills = c.skills // {
        load.extraDirs = [ (builtins.head c.skills.load.extraDirs) ] ++ (person.extraSkillFolders or [ ]);
      };
      tools = c.tools // {
        allow = lib.filter (tool: !(lib.hasPrefix "claw-scryer-${person.name}__" tool)) c.tools.allow;
      };
    };
  # Avoid leaving original dynamic agent entries alongside the normalized one.
  normalized =
    person: c:
    let
      n = normalize person c;
    in
    n
    // {
      agents = n.agents // {
        entries = { inherit (n.agents.entries) person; };
      };
    };
  common = normalized people.simon configs.simon;
  same = common == normalized people.laure configs.laure;
  valid =
    name: person:
    let
      container = host.containers.${person.nodeName};
      c = configs.${name};
      unit = container.config.systemd.services.openclaw-gateway.serviceConfig;
      node = container.config.systemd.services.openclaw-session-share;
    in
    assert lib.attrNames c.agents.entries == [ person.agentId ];
    assert !(c.agents.entries.${person.agentId} ? tools);
    assert c.gateway.auth.trustedProxy.allowUsers == [ person.login ];
    assert c.gateway.roles.default == "person";
    assert c.gateway.roles.definitions.person.sessions.others == "write";
    assert c.gateway.roles.definitions.person.agents == [ person.agentId ];
    assert !(lib.elem "operator.admin" c.gateway.roles.definitions.person.scopes);
    assert c.agents.entries.${person.agentId}.identity == person.identity;
    assert
      c.tools.deny == [ "group:runtime" ] && !c.tools.elevated.enabled && !c.tools.codeMode.enabled;
    assert
      lib.attrNames c.mcp.servers == lib.sort builtins.lessThan (
        [
          "claw-maps"
          "claw-websearch"
        ]
        ++ lib.attrNames person.mcpServers
      );
    assert c.plugins.entries.session-share.config.share.groups == [ "Shared" ];
    assert c.plugins.entries.session-share.enabled && lib.elem "session-share" c.plugins.allow;
    assert node.serviceConfig.User == "openclaw";
    assert node.environment.OPENCLAW_STATE_DIR == "/var/lib/openclaw";
    assert lib.hasInfix "--commands openclaw.sessions.list.v1,openclaw.sessions.read.v1" (
      builtins.readFile node.serviceConfig.ExecStart
    );
    assert c.mcp.apps.sandboxOrigin == "https://${person.nodeName}.hummingbird-lake.ts.net:8443";
    assert unit.MemoryMax == "8G" && unit.KillMode == "mixed" && unit.TimeoutStopSec == 35;
    assert container.bindMounts."/nix/var/nix/profiles/apps".isReadOnly;
    assert lib.pathExists "${builtins.head c.skills.load.extraDirs}/research/SKILL.md";
    assert lib.pathExists "${builtins.head c.skills.load.extraDirs}/scryer/SKILL.md";
    true;
in
assert same;
# Prove the drift comparison rejects a change outside the personal allowlist.
assert common != normalized people.laure (configs.laure // { discovery.mdns.mode = "all"; });
assert lib.all (name: valid name people.${name}) (lib.attrNames people);
true
