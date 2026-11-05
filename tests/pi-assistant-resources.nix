# Exercise the public instance options, including the shared Household role.
{ flake }:
let
  system = flake.nixosConfigurations.rakku.extendModules {
    modules = [
      {
        mountainous.features.pi-assistant.sharedSkills.shared-probe =
          "/nix/var/nix/profiles/per-user/pi-assistant/shared-probe";
        mountainous.features.pi-assistant.household = {
          voicePort = 4397;
          skills.probe = "/nix/var/nix/profiles/per-user/pi-assistant/probe-skill";
          credentials.probe = "/run/secrets/probe";
        };
      }
    ];
  };
  config = system.config;
  installed = config.mountainous.features.pi-assistant.installedSkills;
  cfg = config.mountainous.features.pi-assistant;
  unit = name: config.systemd.services."pi-assistant-${name}";
  credential = "scryer-admin-password:${config.sops.secrets.scryer-admin-password.path}";
in
assert cfg.people.simon.apps.google.port == 3171;
assert cfg.people.simon.apps.maps.port == 3172;
assert
  cfg.people.simon.apps.google.readOnlyTools == [
    "calendar_busy"
    "mail_list"
    "mail_read"
    "mail_proposals"
  ];
assert cfg.people.simon.apps.maps.readOnlyTools == [ "travel_time" ];
assert !(cfg.people.laure.apps ? google) && !(cfg.household ? apps);
assert config.systemd.services.assistant-app-simon-google.environment.GOG_KEYRING_BACKEND == "file";
assert
  config.systemd.services.assistant-app-simon-google.environment.MECHANICAL_MODEL == "gpt-6.1-sol";
assert config.systemd.services.assistant-app-simon-google.environment.TZ == "America/Denver";
assert
  config.systemd.services.assistant-app-simon-maps.environment.VALHALLA_URL
  == "https://valhalla.hummingbird-lake.ts.net";
assert builtins.elem
  "gog-keyring-password:${config.sops.secrets.pi-assistant-google-keyring-password.path}"
  config.systemd.services.assistant-app-simon-google.serviceConfig.LoadCredential;
assert config.mountainous.features.ai-gateway.settings.providers.typesafe.prepaid;
assert cfg.household.skills.probe == "/nix/var/nix/profiles/per-user/pi-assistant/probe-skill";
assert builtins.elem "probe:/run/secrets/probe" (unit "household").serviceConfig.LoadCredential;
assert builtins.all (name: builtins.elem credential (unit name).serviceConfig.LoadCredential) [
  "simon"
  "laure"
  "household"
];
assert builtins.all (name: (unit name).serviceConfig.User == "pi-${name}") [
  "simon"
  "laure"
  "household"
];
# Shared skills reach every instance, beside its own skills.
assert builtins.all
  (name: installed.${name}.shared-probe == "/nix/var/nix/profiles/per-user/pi-assistant/shared-probe")
  [
    "simon"
    "laure"
    "household"
  ];
assert installed.household.probe == "/nix/var/nix/profiles/per-user/pi-assistant/probe-skill";
assert !(installed.laure ? probe);
assert installed.simon.scryer == cfg.people.simon.skills.scryer;
# Shared packages reach every instance's PATH.
assert builtins.all
  (name: builtins.all (package: builtins.elem package (unit name).path) cfg.sharedPackages)
  [
    "simon"
    "laure"
    "household"
  ];
# eBay acts in Simon's name: only his assistant loads it or its secrets.
assert cfg.people.simon.extensions ? ebay-seller;
assert (unit "simon").serviceConfig.EnvironmentFile != [ ];
assert builtins.all (name: (unit name).serviceConfig.EnvironmentFile == [ ]) [
  "laure"
  "household"
];
assert !(cfg.people.laure.extensions ? ebay-seller) && !(cfg.household.extensions ? ebay-seller);
assert cfg.household.skills.scryer == cfg.people.simon.skills.scryer;
assert cfg.household.skills.scryer == cfg.people.laure.skills.scryer;
# Personal instances route to Household's loopback RPC, never its web port.
assert builtins.all
  (
    name:
    (unit name).environment.ASSISTANT_HOUSEHOLD_RPC_URL
    == "http://127.0.0.1:${toString cfg.household.voicePort}/rpc"
  )
  [
    "simon"
    "laure"
  ];
assert !((unit "household").environment ? ASSISTANT_HOUSEHOLD_RPC_URL);
assert (unit "household").environment.ASSISTANT_PORT == toString cfg.household.voicePort;
# Only Simon can publish assistant warnings. The fleet CLI owns auth and schema.
assert builtins.elem flake.packages.x86_64-linux.notify-sync (unit "simon").path;
assert (unit "simon").environment.NOTIFY_URL == config.mountainous.notifications.server;
assert
  (unit "simon").environment.NOTIFY_TOKEN_FILE
  == "/run/credentials/pi-assistant-simon.service/notify-token";
assert builtins.elem "notify-token:${config.sops.secrets.notify-agent-token.path}"
  (unit "simon").serviceConfig.LoadCredential;
assert
  (unit "simon").environment.NOTIFY_BUTTON_TOKEN_FILE
  == "/run/credentials/pi-assistant-simon.service/notify-button-token";
assert builtins.elem "notify-button-token:${config.sops.secrets.notify-button-token.path}"
  (unit "simon").serviceConfig.LoadCredential;
assert builtins.all
  (
    name:
    !((unit name).environment ? NOTIFY_TOKEN_FILE)
    && !((unit name).environment ? NOTIFY_BUTTON_TOKEN_FILE)
    && !((unit name).environment ? NOTIFY_URL)
    && !(builtins.elem flake.packages.x86_64-linux.notify-sync (unit name).path)
    && !(builtins.any (
      credential: builtins.match "notify-(button-)?token:.*" credential != null
    ) (unit name).serviceConfig.LoadCredential)
    && !((unit name).environment ? ASSISTANT_LOGBOOK_URL)
  )
  [
    "laure"
    "household"
  ];
assert (unit "simon").environment.ASSISTANT_LOGBOOK_URL == "http://127.0.0.1:3160";
true
