# Home Assistant runs as the official container image; Z-Wave JS runs natively.
#
# The split between Nix and Home Assistant:
# - Nix owns the version (the image digest below), the host plumbing (serial
#   device, ports, persistence) and the Z-Wave server. Changing these needs a
#   nixos-rebuild.
# - Home Assistant owns everything in /var/lib/hass, configuration.yaml
#   included. People and agents change it through the UI, the REST/WebSocket
#   API or the MCP server, with no rebuild. The image carries every
#   integration and installs custom ones at runtime.
# - Reproducibility of that state comes from a local git repository in
#   /var/lib/hass, committed by a timer, and from Home Assistant's own backups.
#   The repository holds credentials: it stays on this host and is never pushed.
#
# Upgrade: change `image` to the new tag and its index digest
# (`skopeo inspect docker://ghcr.io/home-assistant/home-assistant:<tag>`).
# If the zwave_js integration then reports "Invalid server version", move the
# `zwave-js-server-src` input to a release with that schema and update
# npmDepsHash below.
{ inputs, ... }:
{
  nixos.modules.home-automation =
    { config, lib, pkgs, ... }:
    let
      configDir = "/var/lib/hass";
      port = 8123;
      zigbeeRadio = "/dev/serial/by-id/usb-Silicon_Labs_HubZ_Smart_Home_Controller_61600558-if01-port0";

      zwaveServer = pkgs.zwave-js-server.overrideAttrs (_: {
        version = "3.12.0";
        src = inputs.zwave-js-server-src;
        npmDeps = pkgs.fetchNpmDeps {
          src = inputs.zwave-js-server-src;
          name = "zwave-js-server-3.12.0-npm-deps";
          hash = "sha256-BirJSLT6HbdD78RmS1Vyq+g4j0x4K8nKEdWeGDz+L3k=";
        };
      });

      # Written only when configuration.yaml is missing or is a link left by the
      # NixOS module. After that the file belongs to Home Assistant.
      seedConfiguration = pkgs.writeText "configuration.yaml" ''
        automation: !include automations.yaml
        binary_sensor: !include binary_sensors.yaml
        group: !include groups.yaml
        history: {}
        homeassistant:
          external_url: https://habitat.hummingbird-lake.ts.net
          internal_url: http://localhost:${toString port}
          name: Home
          temperature_unit: C
          time_zone: America/Denver
          unit_system: metric
        http:
          server_port: ${toString port}
          trusted_proxies:
          - ::1
          - 127.0.0.1
          use_x_forwarded_for: true
        input_boolean: !include input_booleans.yaml
        input_datetime: !include input_datetime.yaml
        input_number: !include input_number.yaml
        logbook: {}
        lovelace:
          mode: storage
        media_source: {}
        recorder: {}
        scene: !include scenes.yaml
        script: !include scripts.yaml
        sensor: !include sensors.yaml
        tts:
        - platform: google_translate
          service_name: google_translate_say
      '';

      # What the config history leaves out: databases, logs, caches, runtime
      # files and state that changes every minute.
      seedGitignore = pkgs.writeText "hass.gitignore" ''
        *.db
        *.db-shm
        *.db-wal
        *.log*
        .cache/
        __pycache__/
        *.pyc
        .ha_run.lock
        deps/
        tts/
        backups/
        .cloud/
        .storage/core.restore_state
        .storage/trace.saved_traces
        .storage/auth
        .storage/*.bak-*
        *.bak
        *.backup
      '';

      commitConfig = pkgs.writeShellApplication {
        name = "hass-config-commit";
        runtimeInputs = [ pkgs.git ];
        text = ''
          cd ${configDir}
          export GIT_AUTHOR_NAME="rakku" GIT_AUTHOR_EMAIL="root@rakku"
          export GIT_COMMITTER_NAME="rakku" GIT_COMMITTER_EMAIL="root@rakku"
          if [ ! -d .git ]; then
            git init --quiet --initial-branch=main
          fi
          install -m 0644 ${seedGitignore} .gitignore
          git add --all
          if ! git diff --cached --quiet; then
            git commit --quiet -m "snapshot $(date -u +%Y-%m-%dT%H:%MZ)"
          fi
        '';
      };
    in
    {
      virtualisation.oci-containers.backend = "podman";
      virtualisation.oci-containers.containers.home-assistant = {
        # 2026.11.2, multi-arch index digest.
        image = "ghcr.io/home-assistant/home-assistant:2026.11.2@sha256:493a07e8f6530fc640223f4a0a5248f20a61ca2f718bb1d31efbf08a2c5ea28f";
        # Keep the unit name, so units ordered after home-assistant.service
        # and the habit `systemctl restart home-assistant` still work.
        serviceName = "home-assistant";
        environment.TZ = "America/Denver";
        volumes = [
          "${configDir}:/config"
          "/run/dbus:/run/dbus:ro"
        ];
        # The ZHA config entry stores this path; keep it the same inside.
        devices = [ "${zigbeeRadio}:${zigbeeRadio}" ];
        extraOptions = [
          "--network=host"
          "--cap-add=NET_ADMIN"
          "--cap-add=NET_RAW"
        ];
      };

      systemd.services.home-assistant = {
        wants = [
          "network-online.target"
          "home-assistant-config-seed.service"
        ];
        after = [
          "network-online.target"
          "home-assistant-config-seed.service"
          "zwave-js.service"
        ];
        # Never pull the image into the tmpfs root. The host persists
        # /var/lib/containers (disks/rakku-existing.nix).
        unitConfig.RequiresMountsFor = [
          "/var/lib/containers"
          configDir
        ];
      };

      systemd.services.home-assistant-config-seed = {
        description = "Seed Home Assistant configuration.yaml";
        unitConfig.RequiresMountsFor = [ configDir ];
        serviceConfig.Type = "oneshot";
        script = ''
          f=${configDir}/configuration.yaml
          if [ -L "$f" ] || [ ! -e "$f" ]; then
            rm -f "$f"
            install -m 0644 ${seedConfiguration} "$f"
          fi
        '';
      };

      systemd.services.hass-config-commit = {
        description = "Commit Home Assistant configuration changes to the local history";
        unitConfig.RequiresMountsFor = [ configDir ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe commitConfig;
          Nice = 10;
        };
      };
      systemd.timers.hass-config-commit = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*:0/15";
          Persistent = true;
        };
      };

      services.zwave-js = {
        enable = true;
        package = zwaveServer;
        port = 3000;
        secretsConfigFile = config.sops.secrets.zwave-js-secrets.path;
        # The server protocol has no authentication, and Home Assistant
        # connects on this host. Listen on loopback only, and do not
        # advertise an address that nothing else can reach.
        extraFlags = [
          "--host"
          "127.0.0.1"
          "--disable-dns-sd"
        ];
      };

      networking.firewall.allowedTCPPorts = [ port ];

      # Files from the native service keep their owner, so a rollback to it
      # still works. The container itself runs as root.
      users.users.hass = {
        isSystemUser = true;
        group = "hass";
        uid = 286;
        home = configDir;
        extraGroups = [ "dialout" ];
      };
      users.groups.hass.gid = 286;
    };
}
