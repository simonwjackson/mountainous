{ inputs, lib, ... }:
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
  mountainous.appProfiles.pi = {
    package =
      system:
      let
        pkgs = inputs.nixpkgs.legacyPackages.${system};
        agent = inputs.pi.packages.${system}.coding-agent-bun;
        wrapper = pkgs.writeShellApplication {
          name = "pi";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.util-linux
          ];
          text = ''
            if [[ "''${1:-}" == "--version" || "''${1:-}" == "--help" ]]; then
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
                  options = "bind,ro";
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
