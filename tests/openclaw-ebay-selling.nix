{ lib, container }:
let
  job = import ../lib/openclaw-ebay-selling.nix;
  unit = container.systemd.services.openclaw-ebay-selling;
in
assert job.declarationKey == "mountainous:ebay-selling";
assert job.name == "ebay-selling" && job.enabled && job.agentId == "main";
assert
  job.schedule == {
    kind = "cron";
    expr = "0 8 * * *";
    tz = "America/Denver";
    staggerMs = 0;
  };
assert job.sessionTarget == "isolated" && job.sessionKey == "agent:main:main";
assert job.delivery == { mode = "announce"; };
assert job.payload.kind == "agentTurn" && job.payload.timeoutSeconds == 300;
assert lib.all (text: lib.hasInfix text job.payload.message) [
  "ebay_messages"
  "ebay_offers"
  "ebay_listings"
  "ebay_drafts"
  "ebay_draft_reply"
  "ebay_draft_offer"
  "ebay_draft_price"
  "over 60 days"
  "at most 3"
  "NO_REPLY"
  "untrusted"
  "multi-quantity"
];
assert unit.after == [ "openclaw-gateway.service" ];
assert unit.requires == [ "openclaw-gateway.service" ];
assert unit.partOf == [ "openclaw-gateway.service" ];
assert unit.wantedBy == [ "multi-user.target" ];
assert unit.serviceConfig.Type == "oneshot" && unit.serviceConfig.RemainAfterExit;
assert unit.serviceConfig.Restart == "on-failure";
true
