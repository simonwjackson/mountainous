{
  rakku,
  yari,
  lib,
}:
let
  cfg = rakku.services.mindwtr;
  route = rakku.mountainous.tailnetNames.ai.mcpRoutes.mindwtr;
  rows = import ../lib/ai-mcp-rows.nix;
  tools = rows.mindwtr.tools;
  simon = yari.containers.claw-simon.config.services.openclaw-gateway.config;
  laure = yari.containers.openclaw.config.services.openclaw-gateway.config;
  persisted = map (p: p.directory) rakku.environment.persistence."/tundra/permafrost".directories;
in
assert cfg.enable && cfg.web.enable && cfg.mcp.enable && cfg.mcp.write;
assert cfg.bindAddress == "127.0.0.1" && cfg.mcp.bindAddress == "127.0.0.1";
assert cfg.stateDir == "/var/lib/mindwtr" && lib.elem cfg.stateDir persisted;
assert rakku.users.users.mindwtr.uid == 951 && rakku.users.groups.mindwtr.gid == 951;
assert rakku.systemd.services.mindwtr-cloud.serviceConfig.ProtectSystem == "strict";
assert rakku.systemd.services.mindwtr-cloud.unitConfig.RequiresMountsFor == [ cfg.stateDir ];
assert cfg.cloud.tokenFile == rakku.sops.secrets.mindwtr-cloud-token.path;
assert cfg.mcp.tokenFile == rakku.sops.secrets.mindwtr-mcp-token.path;
assert rakku.mountainous.tailnetNames.tasks.backend == "http://127.0.0.1:4592";
assert route.backend == "http://127.0.0.1:8723/mcp";
assert route.callerNodeIds == [ (import ../lib/tailnet-nodes.nix).flakey ];
assert route.bearerCredentialFile == cfg.mcp.tokenFile;
assert route.mcpTools == tools;
assert simon.mcp.servers.mindwtr.url == "https://ai.hummingbird-lake.ts.net/mcp/mindwtr";
assert simon.mcp.servers.mindwtr.toolFilter.include == tools;
assert lib.all (tool: lib.elem "mindwtr__${tool}" simon.tools.allow) tools;
assert !(laure.mcp.servers ? mindwtr);
assert !lib.any (tool: lib.hasPrefix "mindwtr" tool) laure.tools.allow;
assert lib.pathExists "${builtins.elemAt simon.skills.load.extraDirs 1}/tasks/SKILL.md";
assert !(lib.pathExists "${builtins.elemAt laure.skills.load.extraDirs 1}/tasks/SKILL.md");
true
