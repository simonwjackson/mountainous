{
  config,
  inputs,
  lib,
  ...
}:
let
  flake = config;
in
{
  nixos.modules.base =
    { config, lib, ... }:
    {
      mountainous.appUpdates.pi = lib.mkIf (config.networking.hostName == "unzen") {
        input = "pi";
        schedule = "*-*-* 00,06,12,18:00:00 UTC";
        hosts = lib.attrNames flake.nixos.hosts;
        substituters = [
          "https://pi.cachix.org"
          "https://nix-community.cachix.org"
        ];
        trustedPublicKeys = [
          "pi.cachix.org-1:lGeoGJaZ5ZDabuRzkcD5EBTNnDM4HJ1vqeOxlWk1Flk="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];
      };
    };

  # Fuji remains a builder without Syncthing. Its pi settings stay local.
  mountainous.fleetSync.folders.pi = {
    hosts = lib.remove "fuji" (lib.attrNames flake.nixos.hosts);
    files = [ "settings.json" ];
  };

  mountainous.appProfiles.pi = {
    package =
      system:
      let
        pkgs = inputs.nixpkgs.legacyPackages.${system};
        agent = inputs.pi.packages.${system}.coding-agent-bun;
        wrapper = pkgs.writeShellApplication {
          name = "pi";
          runtimeInputs = [ pkgs.coreutils ];
          text = ''
            if [[ "$#" == 1 && ( "$1" == "--version" || "$1" == "--help" ) ]]; then
              PI_OFFLINE=1 exec ${agent}/bin/pi "$@"
            fi
            agent_dir=''${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}
            umask 077
            mkdir -p "$agent_dir/tmp"
            # The provider imports a predictable filename. Never share /tmp.
            export TMPDIR
            TMPDIR=$(mktemp -d "$agent_dir/tmp/run.XXXXXXXXXX")
            trap 'rm -rf -- "$TMPDIR"' EXIT
            export PI_OFFLINE=1
            export CLIPROXYAPI_BASE_URL=https://cliproxyapi.hummingbird-lake.ts.net
            export CLIPROXYAPI_API_KEY PI_DECIDE_API_KEY
            CLIPROXYAPI_API_KEY=$(cat /run/secrets/pi-cliproxyapi-api-key)
            PI_DECIDE_API_KEY=$(cat /run/secrets/pi-decide-api-key)
            ${agent}/bin/pi \
              -e ${inputs.pi-cliproxyapi-provider}/extensions/index.ts \
              -e ${./pi-decide.ts} "$@"
          '';
        };
      in
      wrapper.overrideAttrs (_: {
        version = agent.version;
      });

    hostModule =
      { config, lib, ... }:
      let
        home = config.users.users.simon.home;
      in
      lib.mkIf config.mountainous.appProfiles.pi.enable {
        sops.secrets.pi-cliproxyapi-api-key = {
          owner = "simon";
          mode = "0400";
        };
        sops.secrets.pi-decide-api-key = {
          owner = "simon";
          mode = "0400";
        };
        systemd.tmpfiles.rules = [
          "d ${home}/.pi 0700 simon users -"
          "d ${home}/.pi/agent 0700 simon users -"
          "d ${home}/.local 0755 simon users -"
          "d ${home}/.local/share 0755 simon users -"
          "d ${home}/.local/share/fleet-sync 0700 simon users -"
          "d ${home}/.local/share/fleet-sync/pi 0700 simon users -"
          # Never replace a pre-existing settings file. Migrate it explicitly.
          "L ${home}/.pi/agent/settings.json - - - - ${home}/.local/share/fleet-sync/pi/settings.json"
        ];
      };
  };
}
