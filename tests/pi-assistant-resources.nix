# Exercise the public instance options, including the shared Household role.
{ flake }:
let
  system = flake.nixosConfigurations.rakku.extendModules {
    modules = [
      {
        mountainous.features.pi-assistant.sharedSkills.shared-probe =
          "/nix/var/nix/profiles/per-user/pi-assistant/shared-probe";
        mountainous.features.pi-assistant.household = {
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
true
