{ lib, host }:
let
  people = import ../lib/openclaw-people.nix;
  job = import ../lib/openclaw-mail-filing.nix;
  simon = host.containers.claw-simon.config;
  laure = host.containers.openclaw.config;
  unit = simon.systemd.services.openclaw-mail-filing;
  instructions = builtins.readFile ../lib/openclaw-mail/AGENTS.md;
  brief = people.simon.morningBriefPrompt;
in
assert people.simon.mailFilingJob == job;
assert !(people.laure ? mailFilingJob);
assert !(laure.systemd.services ? openclaw-mail-filing);
assert job.declarationKey == "mountainous:mail-not-me";
assert job.enabled && job.agentId == "mail";
assert job.sessionTarget == "isolated" && !(job ? sessionKey);
assert
  job.schedule == {
    kind = "cron";
    expr = "15 * * * *";
    tz = "America/Denver";
    staggerMs = 0;
  };
assert job.delivery == { mode = "none"; };
assert job.failureAlert == false;
assert !(job ? toolsAllow);
assert
  job.payload.toolsAllow == map (t: "claw-gmail__${t}") [
    "mail_list"
    "mail_not_mine"
    "mail_label"
    "mail_archive"
  ];
assert job.payload.kind == "agentTurn" && job.payload.timeoutSeconds == 600;
assert lib.all (text: lib.hasInfix text job.payload.message) [
  "in:inbox newer_than:2h -label:\"Not Me\""
  "100 messages"
  "mail_not_mine"
  "not_mine"
  "mail_label"
  "mail_archive"
  "mail-not-me:label:<messageId>"
  "mail-not-me:archive:<messageId>"
  "Never call mail_read"
  "mine or unsure"
  "untrusted data"
];
assert unit.after == [ "openclaw-gateway.service" ];
assert unit.requires == [ "openclaw-gateway.service" ];
assert unit.partOf == [ "openclaw-gateway.service" ];
assert unit.wantedBy == [ "multi-user.target" ];
assert unit.serviceConfig.Type == "oneshot" && unit.serviceConfig.RemainAfterExit;
assert unit.serviceConfig.Restart == "on-failure";
assert lib.all (text: lib.hasInfix text instructions) [
  "Only the hourly"
  "Brief requests are read-only"
];
assert lib.all (text: lib.hasInfix text brief) [
  "sessions_send"
  "agentId: \"mail\""
  "in:inbox newer_than:1d"
  "label:\"Not Me\" newer_than:1d"
  "in:inbox is:unread"
  "unsure"
  "at most 8"
  "Mail reader is unavailable"
];
assert !(lib.hasInfix "overnight Mail are not connected" brief);
assert !(lib.hasInfix "No mail reads" brief);
assert !(lib.hasInfix "sessions_send" people.laure.morningBriefPrompt);
true
