{
  config,
  inputs,
  lib,
  self,
  ...
}:
let
  flake = config;
in
let
  settings = {
    defaultProvider = "cliproxyapi";
    defaultModel = "gpt-5.6-sol";
    defaultThinkingLevel = "xhigh";
    quietStartup = true;
    collapseChangelog = true;
    theme = "tokyo-night-dark";
    compaction = {
      enabled = true;
      reserveTokens = 16384;
      keepRecentTokens = 20000;
    };
    hideThinkingBlock = true;
    steeringMode = "one-at-a-time";
    transport = "sse";
    enableInstallTelemetry = false;
  };
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
  perSystem =
    { pkgs, system, ... }:
    {
      checks = lib.optionalAttrs pkgs.stdenv.hostPlatform.isx86_64 {
        pi-patch-context = pkgs.runCommand "pi-patch-context" { nativeBuildInputs = [ pkgs.python3 ]; } ''
          python3 ${../tests/pi/test_policy_patch.py} ${./pi-settings-policy.py} \
            ${
              inputs.pi.packages.${system}.coding-agent-bun
            }/lib/node_modules/@earendil-works/pi-coding-agent/dist
          touch $out
        '';
        pi-policy = import ../tests/pi/policy.nix {
          inherit pkgs inputs;
          verifyBootOrder = import ../tests/pi/boot-order.nix {
            inherit pkgs;
            unitText =
              self.nixosConfigurations.unzen.config.systemd.units."var-lib-pi-simon-agent-settings.json.mount".text;
            systemd = self.nixosConfigurations.unzen.config.systemd.package;
          };
          profile = flake.mountainous.appProfiles.pi;
          agent = self.packages.${system}.app-pi.policyAgent;
          runtime = self.packages.${system}.app-pi.policyRuntime;
        };
      };
    };
  mountainous.appProfiles.pi = {
    package =
      system:
      let
        pkgs = inputs.nixpkgs.legacyPackages.${system};
        agent = inputs.pi.packages.${system}.coding-agent-bun.overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.python3 ];
          postInstall = (old.postInstall or "") + ''
            python3 ${./pi-settings-policy.py} "$out/lib/node_modules/@earendil-works/pi-coding-agent/dist"
          '';
          preInstallCheck = (old.preInstallCheck or "") + ''
            export PI_CODING_AGENT_DIR
            PI_CODING_AGENT_DIR=$(mktemp -d)
            cp ${pkgs.writeText "pi-policy.json" (builtins.toJSON settings)} "$PI_CODING_AGENT_DIR/settings.json"
            chmod 0444 "$PI_CODING_AGENT_DIR/settings.json"
            export PI_OFFLINE=1
          '';
          installCheckPhase = (old.installCheckPhase or "") + ''
            policyDir=$(mktemp -d)
            cp ${pkgs.writeText "pi-policy.json" (builtins.toJSON settings)} "$policyDir/settings.json"
            chmod 0444 "$policyDir/settings.json"
            bun ${../tests/pi/settings-policy.mjs} \
              "$out/lib/node_modules/@earendil-works/pi-coding-agent/dist/core/settings-manager.js" \
              "$policyDir" "$policyDir/settings.json"
          '';
        });
        wrapper = pkgs.writeShellApplication {
          name = "pi";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.util-linux
          ];
          text = ''
            if [[ "$#" == 1 && ( "$1" == "--version" || "$1" == "--help" ) ]]; then
              export PI_CODING_AGENT_DIR=${pkgs.writeTextDir "settings.json" (builtins.toJSON settings)}
              export PI_OFFLINE=1
              exec ${agent}/bin/pi "$@"
            fi
            user=$(id -un)
            export PI_CODING_AGENT_DIR="/var/lib/pi/$user/agent"
            if [[ ! -d "$PI_CODING_AGENT_DIR" || ! -O "$PI_CODING_AGENT_DIR" ]]; then
              echo "pi: no provisioned agent directory for $user" >&2
              exit 1
            fi
            mount_options=$(findmnt -rn --mountpoint "$PI_CODING_AGENT_DIR/settings.json" -o VFS-OPTIONS || true)
            if [[ ",$mount_options," != *,ro,* ]]; then
              echo "pi: settings read-only bind mount is not ready" >&2
              exit 1
            fi
            # A unique directory defeats pre-created files AND malicious symlinks.
            umask 077
            export TMPDIR
            TMPDIR=$(mktemp -d "$PI_CODING_AGENT_DIR/tmp/run.XXXXXXXXXX")
            trap 'rm -rf -- "$TMPDIR"' EXIT
            export CLIPROXYAPI_BASE_URL=https://cliproxyapi.hummingbird-lake.ts.net
            export CLIPROXYAPI_API_KEY
            CLIPROXYAPI_API_KEY=$(cat /run/secrets/pi-cliproxyapi-api-key)
            # Nix owns settings, including telemetry. PI_OFFLINE also suppresses
            # network startup probes; changelog stays collapsed across updates.
            export PI_OFFLINE=1
            ${agent}/bin/pi -e ${inputs.pi-cliproxyapi-provider}/extensions/index.ts "$@"
          '';
        };
      in
      wrapper.overrideAttrs (_: {
        version = agent.version;
        passthru.policyAgent = agent;
        passthru.policyRuntime = inputs.pi.inputs.nixpkgs.legacyPackages.${system}.bun;
      });
    hostModule =
      {
        config,
        lib,
        pkgs,
        options,
        ...
      }:
      let
        enabled = config.mountainous.appProfiles.pi.enable;
        file = pkgs.writeText "pi-settings.json" (builtins.toJSON settings);
      in
      {
        config = lib.mkIf enabled (
          lib.mkMerge [
            {
              sops.secrets.pi-cliproxyapi-api-key = {
                owner = "simon";
                mode = "0400";
              };
              systemd.tmpfiles.rules = [
                "d /var/lib/pi 0755 root root -"
                "d /var/lib/pi/simon 0755 root root -"
                "d /var/lib/pi/simon/agent 0700 simon users -"
                "d /var/lib/pi/simon/agent/tmp 0700 simon users -"
                "f /var/lib/pi/simon/agent/settings.json 0444 root root -"
              ];
              systemd.mounts = [
                {
                  what = toString file;
                  where = "/var/lib/pi/simon/agent/settings.json";
                  type = "none";
                  # nofail removes the implicit Before=local-fs.target edge:
                  # tmpfiles itself starts after local-fs.target.
                  options = "bind,ro,nofail";
                  wantedBy = [ "multi-user.target" ];
                  after = [ "systemd-tmpfiles-setup.service" ];
                  requires = [ "systemd-tmpfiles-setup.service" ];
                  # NixOS restarts a changed mount unit when the store source changes.
                  restartTriggers = [ file ];
                }
              ];
            }
            (lib.optionalAttrs (options.environment ? persistence) {
              environment.persistence."${
                if config.mountainous ? permafrost then "/permafrost" else "/tundra/permafrost"
              }".directories =
                [ "/var/lib/pi" ];
            })
          ]
        );
      };
  };
}
