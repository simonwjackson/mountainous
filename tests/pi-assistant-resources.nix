# Exercise the public instance options, including the shared Household role.
{ flake }:
let
  system = flake.nixosConfigurations.rakku.extendModules {
    modules = [
      {
        mountainous.features.pi-assistant.household = {
          skills.probe = "/nix/var/nix/profiles/per-user/pi-assistant/probe-skill";
          credentials.probe = "/run/secrets/probe";
        };
      }
    ];
  };
  config = system.config;
  cfg = config.mountainous.features.pi-assistant;
  unit = name: config.systemd.services."pi-assistant-${name}";
  credential = "scryer-admin-password:${config.sops.secrets.scryer-admin-password.path}";
in
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
assert cfg.household.skills.scryer == cfg.people.simon.skills.scryer;
assert cfg.household.skills.scryer == cfg.people.laure.skills.scryer;
true
