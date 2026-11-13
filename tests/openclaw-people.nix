# Compare the actual generated gateway configurations, not an input template.
# This allowlist names every permitted difference. A new unlisted difference fails.
{ lib, host }:
let
  people = import ../lib/openclaw-instances.nix {
    legacyEnabled = host.mountainous.features.openclaw.legacy.enable;
  };
  configs = lib.mapAttrs (
    _: person: host.containers.${person.containerName}.config.services.openclaw-gateway.config
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
        roles =
          (builtins.removeAttrs c.gateway.roles [
            "default"
            "definitions"
          ])
          // {
            definitions = (builtins.removeAttrs c.gateway.roles.definitions [ person.roleName ]) // {
              person = builtins.removeAttrs c.gateway.roles.definitions.${person.roleName} [ "agents" ];
            };
          };
        controlUi = builtins.removeAttrs c.gateway.controlUi [ "allowedOrigins" ];
      };
      agents = c.agents // {
        defaults = (builtins.removeAttrs c.agents.defaults [ "workspace" ]) // {
          systemAgent = builtins.removeAttrs c.agents.defaults.systemAgent [ "agentId" ];
          sessionStore = builtins.removeAttrs c.agents.defaults.sessionStore [ "agentId" ];
        };
        entries.person = builtins.removeAttrs agent [
          "identity"
          "agentDir"
          "workspace"
          "tools"
        ];
      };
      talk = builtins.removeAttrs c.talk [ "agentId" ];
      mcp = c.mcp // {
        servers = builtins.removeAttrs c.mcp.servers (
          (lib.attrNames person.mcpServers) ++ map (s: s.name) (person.extraMcpServers or [ ])
        );
        apps = builtins.removeAttrs c.mcp.apps [ "sandboxOrigin" ];
      };
      skills = c.skills // {
        load = c.skills.load // {
          extraDirs = [ (builtins.head c.skills.load.extraDirs) ];
        };
      };
      plugins = c.plugins // {
        allow = lib.filter (id: !(lib.elem id (person.extraPlugins or [ ]))) c.plugins.allow;
      };
      tools = c.tools // {
        agentToAgent = {
          enabled = false;
        };
        allow = lib.filter (
          tool:
          !(lib.elem tool (
            (map (t: "claw-scryer-${person.name}__${t}") [
              "scryer_search"
              "scryer_title"
              "scryer_add"
              "scryer_monitor"
            ])
            ++ (person.extraToolPermissions or [ ])
          ))
        ) c.tools.allow;
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
      container = host.containers.${person.containerName};
      c = configs.${name};
      unit = container.config.systemd.services.openclaw-gateway.serviceConfig;
      node = container.config.systemd.services.openclaw-session-share;
    in
    assert
      lib.attrNames c.agents.entries
      == lib.sort builtins.lessThan ([ person.agentId ] ++ lib.attrNames (person.extraAgents or { }));
    assert (c.agents.entries.${person.agentId}.tools or { }) == (person.agentTools or { });
    assert lib.all (id: c.agents.entries.${id} == person.extraAgents.${id}) (
      lib.attrNames (person.extraAgents or { })
    );
    assert c.tools.agentToAgent == (person.agentToAgent or { enabled = false; });
    assert c.gateway.auth.trustedProxy.allowUsers == [ person.login ];
    assert c.gateway.roles.default == person.roleName;
    assert lib.attrNames c.gateway.roles.definitions == [ person.roleName ];
    assert c.gateway.roles.definitions.${person.roleName}.sessions.others == "write";
    assert c.gateway.roles.definitions.${person.roleName}.agents == [ person.agentId ];
    assert !(lib.elem "operator.admin" c.gateway.roles.definitions.${person.roleName}.scopes);
    assert c.agents.entries.${person.agentId}.identity == person.identity;
    assert c.agents.entries.${person.agentId}.workspace == person.workspacePath;
    assert c.agents.defaults.workspace == person.workspacePath;
    assert
      c.tools.deny == [
        "group:runtime"
        "web_search"
      ]
      && !c.tools.elevated.enabled
      && !c.tools.codeMode.enabled;
    assert
      lib.attrNames c.mcp.servers == lib.sort builtins.lessThan (
        [
          "claw-maps"
          "claw-websearch"
        ]
        ++ lib.attrNames person.mcpServers
        ++ map (server: server.name) (person.extraMcpServers or [ ])
      );
    assert c.plugins.entries.session-share.config.share.groups == [ "Shared" ];
    assert c.plugins.entries.session-share.enabled && lib.elem "session-share" c.plugins.allow;
    assert node.serviceConfig.User == "openclaw";
    assert node.environment.OPENCLAW_STATE_DIR == "/var/lib/openclaw";
    assert lib.hasInfix "--commands openclaw.sessions.list.v1,openclaw.sessions.read.v1" node.script;
    assert c.mcp.apps.sandboxOrigin == "https://${person.nodeName}.hummingbird-lake.ts.net:8443";
    assert unit.MemoryMax == "8G" && unit.KillMode == "mixed" && unit.TimeoutStopSec == 35;
    assert container.bindMounts."/nix/var/nix/profiles/apps".isReadOnly;
    assert lib.length c.skills.load.extraDirs == 2 + lib.length (person.extraSkillFolders or [ ]);
    assert lib.drop 2 c.skills.load.extraDirs == (person.extraSkillFolders or [ ]);
    assert lib.pathExists "${builtins.head c.skills.load.extraDirs}/research/SKILL.md";
    assert lib.pathExists "${builtins.head c.skills.load.extraDirs}/scryer/SKILL.md";
    true;
in
assert (import ../lib/openclaw-people.nix).laure.login == "chancerellelaure@gmail.com";
assert (import ../lib/openclaw-people.nix).laure.containerName == "openclaw";
assert (import ../lib/openclaw-people.nix).laure.nodeName == "claw";
assert (import ../lib/openclaw-people.nix).laure.roleName == "laure";
assert !(import ../lib/openclaw-people.nix).laure.enableMorningBrief;
# Step 2: mail is confined to Simon's restricted reader, never his main agent.
assert
  lib.attrNames configs.simon.agents.entries == [
    "mail"
    "main"
  ];
assert configs.simon.agents.entries.main.tools.deny == [ "claw-gmail__*" ];
assert configs.simon.agents.entries.main.tools.agentToAgent.send == [ "mail" ];
assert
  configs.simon.agents.entries.mail.tools.allow == (map (t: "claw-gmail__${t}") [
    "mail_list"
    "mail_read"
    "mail_not_mine"
    "mail_label"
    "mail_archive"
    "mail_draft"
    "mail_discard_draft"
  ])
  ++ [ "session_status" ];
assert configs.simon.agents.entries.mail.tools.agentToAgent.send == [ ];
assert configs.simon.agents.entries.mail.skills == [ ];
assert configs.simon.agents.entries.mail.tools.exec.mode == "deny";
assert configs.simon.agents.entries.mail.name == "Mail reader";
assert configs.simon.agents.entries.mail.workspace == "/var/lib/openclaw/workspace-mail";
assert configs.simon.agents.entries.mail.agentDir == "/var/lib/openclaw/agents/mail/agent";
assert !(configs.simon.agents.entries.mail ? heartbeat);
assert lib.pathExists "${builtins.elemAt configs.simon.skills.load.extraDirs 1}/mail/SKILL.md";
assert lib.all
  (
    file:
    lib.hasInfix "/${file} /var/lib/openclaw/workspace-mail/${file}"
      host.containers.${people.simon.containerName}.config.systemd.services.openclaw-agent-instructions.script
  )
  [
    "AGENTS.md"
    "SOUL.md"
    "BOOTSTRAP.md"
  ];
assert
  host.containers.${people.simon.containerName}.config.systemd.services.openclaw-agent-instructions.before
  == [ "openclaw-gateway.service" ];
assert
  configs.simon.agents.entries.mail.model.primary == configs.simon.agents.defaults.model.primary;
assert
  configs.simon.tools.agentToAgent == {
    enabled = true;
    allow = [
      "main"
      "mail"
    ];
  };
assert lib.attrNames configs.laure.agents.entries == [ "laure" ];
assert !(configs.laure.mcp.servers ? claw-gmail);
assert !configs.laure.tools.agentToAgent.enabled;
assert configs.simon.tools.sessions.visibility == "agent";
assert same;
# Prove the drift comparison rejects a change outside the personal allowlist.
assert common != normalized people.laure (configs.laure // { discovery.mdns.mode = "all"; });
assert lib.all (name: valid name people.${name}) (lib.attrNames people);
true
