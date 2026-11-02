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
        # Extensions every host loads. Add one by adding a flake input
        # and an entry here. Pi itself supplies the @earendil-works/* and
        # typebox imports, so only package-to-package links are needed.
        askQuestions = pkgs.runCommand "pi-ask-questions" { } ''
          mkdir -p $out/node_modules/@adeildo
          cp -r ${inputs.pi-harness}/packages/kit $out/kit
          cp -r ${inputs.pi-harness}/packages/ask-questions/. $out/
          ln -s ../../kit $out/node_modules/@adeildo/pi-kit
        '';
        # pi-web-access 0.39.0 (Forgerie's pin) and its npm dependencies,
        # locked in pi-web-access/package-lock.json. Pi supplies the peers.
        webAccess = pkgs.importNpmLock.buildNodeModules {
          npmRoot = ./pi-web-access;
          nodejs = pkgs.nodejs;
          derivationArgs.npmFlags = [ "--legacy-peer-deps" "--ignore-scripts" ];
        };
        extensions = [
          "${inputs.pi-cliproxyapi-provider}/extensions/index.ts"
          ./pi-decide.ts
          "${askQuestions}/src/index.ts"
          "${webAccess}/node_modules/pi-web-access/dist/index.js"
        ];
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
            export CLIPROXYAPI_BASE_URL=https://ai.hummingbird-lake.ts.net
            export CLIPROXYAPI_API_KEY PI_DECIDE_API_KEY
            CLIPROXYAPI_API_KEY=$(cat /run/secrets/pi-ai-gateway-api-key)
            PI_DECIDE_API_KEY=$CLIPROXYAPI_API_KEY
            ${agent}/bin/pi \
              ${lib.concatMapStringsSep " " (e: "-e ${e}") extensions} "$@"
          '';
        };
      in
      wrapper.overrideAttrs (_: {
        version = agent.version;
      });

    hostModule =
      { config, lib, pkgs, ... }:
      let
        home = config.users.users.simon.home;
        # Search goes through the AI front door with the host's gateway key,
        # read at call time so it never enters the store. DuckDuckGo needs
        # no key and takes over when the front door fails.
        webSearchConfig = pkgs.writeText "web-search.json" (builtins.toJSON {
          openaiResponsesUrl = "https://ai.hummingbird-lake.ts.net/v1/responses";
          openaiApiKey = "!cat /run/secrets/pi-ai-gateway-api-key";
          openaiSearchModel = "gpt-5.6-luna";
          workflow = "none";
          searchRouting = {
            providers = [ "openai" "duckduckgo" ];
            useCurrentModel = false;
            fallbackOn = [ "unsupported" "transient" "quota" "network" "invalid-response" ];
          };
        });
      in
      lib.mkIf config.mountainous.appProfiles.pi.enable {
        sops.secrets.pi-ai-gateway-api-key = {
          sopsFile = ../secrets/hosts/${config.networking.hostName}.yaml;
          key = "ai-gateway-key-pi-${config.networking.hostName}";
          owner = "simon";
          mode = "0400";
        };
        # Keep retired credentials declared until the separate cleanup.
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
          "L+ ${home}/.pi/agent/web-search.json - - - - ${webSearchConfig}"
        ];
      };
  };
}
