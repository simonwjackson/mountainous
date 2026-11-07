# In-place port of the running Home Assistant host at 192.168.1.178.
# Do not add the shared disk layer or use an installer against this host.
{ config, inputs, ... }:
let
  operatorKey = config.mountainous.sshKey;
in
{
  nixos.hosts.rakku = {
    system = "x86_64-linux";
    layers = [
      "server"
      "home-automation"
      "home-network-services"
      "cliproxyapi"
      "logbook"
      "tailnet-names"
      "decision-gateway"
      "ai-gateway-staging"
      "ai-gateway"
      "notify-server"
      "beszel-hub"
      "pi-assistant"
      "signal-responder"
      "vela"
      "no-builds"
    ];
    module =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        # The eBay seller tools and their runtime dependencies, locked in
        # modules/pi-ebay-seller (runtime only: the upstream lock has entries
        # without integrity). Pi supplies the pi-* and typebox peers.
        ebaySellerModules = pkgs.importNpmLock.buildNodeModules {
          npmRoot = ../pi-ebay-seller;
          nodejs = pkgs.nodejs;
          derivationArgs.npmFlags = [
            "--legacy-peer-deps"
            "--ignore-scripts"
          ];
        };
        ebaySeller = pkgs.runCommand "pi-ebay-seller" { } ''
          mkdir -p $out
          cp -r ${inputs.pi-ebay-seller}/package.json ${inputs.pi-ebay-seller}/extensions $out/
          ln -s ${ebaySellerModules}/node_modules $out/node_modules
        '';
      in
      {
        imports = [
          (inputs.impermanence-rakku + "/nixos.nix")
          ../../disks/rakku-existing.nix
        ];
        # The pinned impermanence leaves fsType unset on its bind mounts. Rakku's
        # old nixpkgs defaulted it to "auto"; the fleet nixpkgs has no default.
        # Keep the deployed fstab entries as they are.
        fileSystems = lib.listToAttrs (
          map (entry: {
            name = entry.dirPath;
            value.fsType = lib.mkDefault "auto";
          }) config.environment.persistence."/tundra/permafrost".directories
        );
        # NeededForUsers decrypts before /etc's persisted file links are set up.
        # This filesystem is mounted in stage 1, so the key exists on cold boot.
        sops.age.sshKeyPaths = lib.mkForce [ "/tundra/permafrost/etc/ssh/ssh_host_ed25519_key" ];
        mountainous.serviceApps.groceries = (import ../../lib/groceries-service.nix { inherit pkgs; }) // {
          input = "groceries";
          port = 4382;
          schedule = "*-*-* 04:15:00 UTC";
        };
        mountainous.serviceApps.knowledge =
          (import ../../lib/knowledge-service.nix { inherit pkgs inputs; })
          // {
            input = "knowledge";
            port = 4381;
            schedule = "*-*-* 04:35:00 UTC";
          };
        mountainous.serviceApps.meetings = {
          input = "meetings";
          port = 8179;
          serverArgs = [ ];
          environment.MEETINGS_DATA_DIR = "/var/lib/meetings/data";
          schedule = "*-*-* 04:40:00 UTC";
          smokeCommand = "${pkgs.curl}/bin/curl -fsS --max-time 3 http://127.0.0.1:8179/healthz >/dev/null";
          checkCommand = ''
            test "$("$APP_PACKAGE/bin/meetings-server" --version)" = "meetings-server $APP_VERSION"
          '';
        };
        mountainous.serviceApps.storia = (import ../../lib/storia-service.nix { inherit pkgs; }) // {
          input = "storia";
          port = 4390;
          schedule = "*-*-* 04:45:00 UTC";
        };
        mountainous.serviceApps.synth = {
          input = "synth";
          server = "synth-serve";
          sidecar = null;
          port = 4180;
          serverArgs = [
            "--name"
            "synth"
            "--expected-fqdn"
            "synth.hummingbird-lake.ts.net"
            "--assets-dir"
            "/nix/var/nix/profiles/apps/synth/share/synth/client"
            "--state"
            "/var/lib/synth/state/tsnet"
            "--local-addr"
            "127.0.0.1:4180"
          ];
          schedule = "*-*-* 04:50:00 UTC";
          smokeCommand = "${pkgs.curl}/bin/curl -fsS --max-time 3 http://127.0.0.1:4180/manifest.webmanifest >/dev/null";
          checkCommand = ''test "$("$APP_PACKAGE/bin/synth-serve" --version)" = "synth-serve $APP_VERSION" '';
        };
        mountainous.serviceApps.pace = (import ../../lib/pace-service.nix { inherit pkgs inputs; }) // {
          input = "pace";
          port = 4321;
          schedule = "*-*-* 04:55:00 UTC";
        };
        # Isolated rollback canary: no tailnet registration or production state.
        mountainous.serviceApps.service-app-canary = {
          package =
            system:
            import ../../tests/fixtures/service-app-canary {
              pkgs = inputs.nixpkgs.legacyPackages.${system};
            };
          rollbackCanary = true;
          port = 4398;
          sidecarArgs = [
            "--host"
            "127.0.0.1"
            "--port"
            "4399"
          ];
          smokeCommand = "${pkgs.curl}/bin/curl -fsS --max-time 3 http://127.0.0.1:4398/healthz >/dev/null";
          schedule = "*-*-* 04:30:00 UTC";
        };
        # Permanent one-process regression canary; no tailnet or credentials.
        mountainous.serviceApps.service-app-single-canary = {
          package =
            system:
            import ../../tests/fixtures/service-app-single-canary {
              pkgs = inputs.nixpkgs.legacyPackages.${system};
            };
          rollbackCanary = true;
          sidecar = null;
          port = 4400;
          serverArgs = [
            "--host"
            "127.0.0.1"
            "--port"
            "4400"
          ];
          smokeCommand = "${pkgs.curl}/bin/curl -fsS --max-time 3 http://127.0.0.1:4400/healthz >/dev/null";
        };
        mountainous.features.ai-gateway-staging.enable = true;
        mountainous.features.ai-gateway.enable = true;
        mountainous.features.notify-server.enable = true;
        # Beszel and storage alerts get a read-only triage by Simon's assistant.
        mountainous.features.signal-responder = {
          enable = true;
          person = "simon";
        };
        mountainous.features.cliproxyapi = {
          enable = true;
          deployPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIGFCc1rafaJq+i2sfHq2RiZdxGMfk/HeNHwKBzGyS7Q cliproxyapi-updater@unzen";
          signingPublicKey = "cliproxyapi-unzen:KgVn63py+E3v950Hko/PdGkqfeSHZjIl0h01bPWac04=";
          geminiApiKeyFile = config.sops.secrets.cliproxyapi-gemini-api-key.path;
        };
        # Rotate the front-door grant and all three credential copies together.
        sops.secrets.ai-gateway-key-assistant-rakku =
          lib.mkIf config.mountainous.features.ai-gateway.enable
            {
              restartUnits = [
                "pi-assistant-simon.service"
                "pi-assistant-laure.service"
                "pi-assistant-household.service"
                "assistant-app-simon-google.service"
              ];
            };
        # eBay seller credentials, from the old agenix ebay-api-env and
        # ebay-refresh-token. Root reads the env file for the simon unit.
        sops.secrets.ebay-api-env = {
          sopsFile = ../../secrets/hosts/rakku.yaml;
          restartUnits = [ "pi-assistant-simon.service" ];
        };
        sops.secrets.ebay-refresh-token = {
          sopsFile = ../../secrets/hosts/rakku.yaml;
          restartUnits = [ "pi-assistant-simon.service" ];
        };
        sops.templates."pi-assistant-simon-ebay.env" = {
          content = ''
            ${config.sops.placeholder.ebay-api-env}
            ${config.sops.placeholder.ebay-refresh-token}
          '';
          restartUnits = [ "pi-assistant-simon.service" ];
        };
        # Nano Banana (Gemini image) key, served through CLIProxyAPI.
        sops.secrets.cliproxyapi-gemini-api-key = {
          sopsFile = ../../secrets/hosts/rakku.yaml;
          owner = "cliproxyapi";
          mode = "0400";
        };
        # Preserve every driver from the original hardware.nix, including USB
        # storage. The general base layer does not carry usb_storage.
        boot.initrd.availableKernelModules = [
          "ahci"
          "xhci_pci"
          "usb_storage"
          "sd_mod"
        ];
        boot.kernelModules = [
          "igb"
          "cp210x"
          "mt7921u"
        ];
        # Keep the DHCP client and NIC identity that already hold the LAN lease.
        networking.networkmanager.enable = lib.mkForce false;
        networking.useDHCP = true;
        networking.wireless.enable = lib.mkForce false;

        # The old host had no firewall. Preserve home discovery/event callbacks
        # on the existing LAN NIC during the port; do not trust the spare NICs.
        networking.firewall = {
          enable = true;
          trustedInterfaces = [
            "enp1s0"
            "tailscale0"
          ];
        };

        services.zwave-js.serialPort = "/dev/serial/by-id/usb-Silicon_Labs_HubZ_Smart_Home_Controller_61600558-if00-port0";
        services.udev.extraRules = ''
          SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="8a2a", ATTRS{bInterfaceNumber}=="00", SYMLINK+="zwave"
          SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="8a2a", ATTRS{bInterfaceNumber}=="01", SYMLINK+="zigbee"
        '';

        # Preserve UID 1000 and the old home. Cairn's account is added, not a
        # destructive rename. Retire the old login only in a separate change.
        users.users.simon.uid = 1001;
        users.users.simonwjackson = {
          isNormalUser = true;
          uid = 1000;
          home = "/home/simonwjackson";
          extraGroups = [
            "wheel"
            "video"
            "dialout"
          ];
          openssh.authorizedKeys.keys = [ operatorKey ];
          hashedPasswordFile = config.sops.secrets.user-password.path;
        };
        security.sudo.extraRules = [
          {
            users = [ "simonwjackson" ];
            commands = [
              {
                command = "ALL";
                options = [ "NOPASSWD" ];
              }
            ];
          }
        ];

        sops.secrets.zwave-js-secrets = {
          sopsFile = ../../secrets/hosts/rakku.yaml;
          mode = "0400";
        };

        # Simon's and Laure's assistants, and their shared one, behind
        # https://assistant.hummingbird-lake.ts.net.
        mountainous.features.pi-assistant = {
          # Simon's ~/.agents/skills, as a snapshot in the shared skills
          # profile, for every assistant: Simon's, Laure's, and the Household's.
          sharedSkills.agents = "/nix/var/nix/profiles/per-user/pi-assistant/skills/agents";
          # The agent-browser skill drives a headless Chromium.
          sharedPackages = [
            pkgs.agent-browser
            pkgs.chromium
          ];
          people = {
            simon = {
              voicePort = 4317;
              webPort = 4318;
              # Simon's assistant clones, pushes, and opens pull requests as him.
              github = true;
              # Training in the Assistant: Logbook on loopback and the Coach skill.
              logbook = true;
              remoteApps.forgerie = {
                title = "Forgerie";
                url = "http://zao.hummingbird-lake.ts.net:3190/mcp";
              };
              # Logbook's dates are [start,end): today and the six preceding days.
              defaultViews.logbook = {
                tool = "days_summary";
                input = {
                  start = "$today-6d";
                  end = "$today+1d";
                };
              };
              # Simon's own apps (assistant/apps, assistant core ADR 0006).
              # The to-do board retired when Atlas replaced it (ADR 0017); its
              # data stays in apps/todo-board as a backup.
              apps.google = {
                title = "Google";
                port = 3171;
                readOnlyTools = [
                  "calendar_busy"
                  "mail_list"
                  "mail_read"
                  "mail_proposals"
                ];
                credentials = {
                  gog-keyring-password = config.sops.secrets.pi-assistant-google-keyring-password.path;
                  decide-api-key = config.sops.secrets.ai-gateway-key-assistant-rakku.path;
                  mechanical-api-key = config.sops.secrets.ai-gateway-key-assistant-rakku.path;
                };
              };
              apps.maps = {
                title = "Maps";
                port = 3172;
                readOnlyTools = [ "travel_time" ];
                environment.VALHALLA_URL = "https://valhalla.hummingbird-lake.ts.net";
              };
              skills.scryer = "/nix/var/nix/profiles/per-user/pi-assistant/skills/scryer";
              skills.coach = "/nix/var/nix/profiles/per-user/pi-assistant/skills/coach";
              credentials.scryer-admin-password = config.sops.secrets.scryer-admin-password.path;
              # eBay acts as Simon (offers, buyer messages), so only his
              # assistant gets it. Laure and Household do not.
              extensions.ebay-seller = ebaySeller;
              environmentFiles = [ config.sops.templates."pi-assistant-simon-ebay.env".path ];
            };
            laure = {
              voicePort = 4327;
              webPort = 4328;
              skills.scryer = "/nix/var/nix/profiles/per-user/pi-assistant/skills/scryer";
              credentials.scryer-admin-password = config.sops.secrets.scryer-admin-password.path;
            };
          };
          household = {
            skills.scryer = "/nix/var/nix/profiles/per-user/pi-assistant/skills/scryer";
            credentials.scryer-admin-password = config.sops.secrets.scryer-admin-password.path;
          };
          tailnet = "hummingbird-lake.ts.net";
          # Vela's /surface link (Vela ADR 0007).
          extraWebOrigins = [ config.mountainous.features.vela.origin ];
          homePlace = "Denver|39.739|-104.985|America/Denver";
          # Keep the compatible option name. The front door now owns this port.
          cliproxyapiPort = 8430;
          cliproxyapiKeyFile = config.sops.secrets.ai-gateway-key-assistant-rakku.path;
          braveApiKeyFile = config.sops.secrets.pi-assistant-brave-api-key.path;
          # Atlas, the shared planning module (sandbox/atlas), for every person.
          atlas = { };
          # The groceries service app on Rakku keeps its existing tailnet node.
          groceries = {
            url = "https://groceries.hummingbird-lake.ts.net";
            tokenFile = config.sops.secrets.pi-assistant-groceries-token.path;
          };
          lanes = {
            chat = "cliproxyapi/claude-opus-5-5";
            creative = "cliproxyapi/claude-opus-5-5";
            mechanical = "cliproxyapi/gpt-6.1-sol";
            background = "cliproxyapi/gemini-3.8-flash-high";
          };
          laneFallbacks = {
            chat = [ "cliproxyapi/gpt-6.1-sol" ];
            creative = [ "cliproxyapi/gpt-6.1-sol" ];
            mechanical = [ "cliproxyapi/claude-opus-5-5" ];
            background = [
              "cliproxyapi/gpt-6.1-sol"
              "cliproxyapi/claude-opus-5-5"
            ];
          };
        };
        # Vela, the car dashboard: https://vela.hummingbird-lake.ts.net.
        # Pyxis (pyxis), Ossicle (podcasts) and voice-gateway (voice) are user
        # units on Zao, outside this flake: pyxis-tsnet, ossicle-proxy and
        # voice-tsnet. Valhalla and Traccar run on Unzen (modules/hosts/unzen.nix).
        mountainous.features.vela.tailnet = config.mountainous.features.pi-assistant.tailnet;
        services.vela.settings = {
          origins =
            let
              at = name: "https://${name}.${config.mountainous.features.vela.tailnet}";
            in
            {
              pyxis = at "pyxis";
              ossicle = at "podcasts";
              assistant = at config.mountainous.features.pi-assistant.tailnetName;
              voice = at "voice";
              valhalla = at "valhalla";
              traccar = at "traccar-osmand";
            };
          photonUrl = "https://photon.komoot.io";
          # Traccar registers this device on its first report.
          traccarDeviceId = "vela";
          # Vela's default; raise it if turn sounds start late over Bluetooth.
          turnSoundLeadMs = 250;
          # The assistant serves each person's SurfaceLink under /people/<name>,
          # and voice-gateway answers Talk with that person's assistant model.
          assistantSurfacePath = "/people/simon/surface";
          talkModel = "simon";
          # Range = fuel level x tank size / recent consumption (Vela ADR 0012).
          # 62 L is the 2016 Mazda 6 figure from research; confirm it from the car.
          tankLitres = 62;
        };

        # Root reads these; each assistant unit gets a copy as a credential.
        # The same media account serves both people and their Household assistant.
        sops.secrets.scryer-admin-password = {
          sopsFile = ../../secrets/hosts/rakku.yaml;
          mode = "0400";
          restartUnits = [
            "pi-assistant-simon.service"
            "pi-assistant-laure.service"
            "pi-assistant-household.service"
          ];
        };
        sops.secrets.pi-assistant-cliproxyapi-key = {
          sopsFile = ../../secrets/hosts/rakku.yaml;
          mode = "0400";
          restartUnits = [
            "pi-assistant-simon.service"
            "pi-assistant-laure.service"
            "pi-assistant-household.service"
          ];
        };
        # Set this value before activation: ./scripts/secrets secrets/hosts/rakku.yaml
        # Only Simon's Google service receives it. No Google sign-in in this build.
        sops.secrets.pi-assistant-google-keyring-password = {
          sopsFile = ../../secrets/hosts/rakku.yaml;
          owner = "root";
          group = "root";
          mode = "0400";
          restartUnits = [ "assistant-app-simon-google.service" ];
        };
        sops.secrets.pi-assistant-brave-api-key = {
          sopsFile = ../../secrets/hosts/rakku.yaml;
          mode = "0400";
          restartUnits = [
            "pi-assistant-simon.service"
            "pi-assistant-laure.service"
            "pi-assistant-household.service"
          ];
        };
        sops.secrets.pi-assistant-groceries-token = {
          sopsFile = ../../secrets/hosts/rakku.yaml;
          mode = "0400";
          restartUnits = [
            "pi-assistant-simon.service"
            "pi-assistant-laure.service"
            "pi-assistant-household.service"
          ];
        };

        # Oura OAuth client secret for Logbook (modules/logbook.nix renders it).
        sops.secrets.oura-api-key = {
          sopsFile = ../../secrets/hosts/rakku.yaml;
          mode = "0400";
        };

        # Withings OAuth client secret for Logbook (modules/logbook.nix renders it).
        sops.secrets.withings-api-key = {
          sopsFile = ../../secrets/hosts/rakku.yaml;
          mode = "0400";
        };

        # Namecheap API key. No service reads it yet.
        sops.secrets.namecheap-api-key = {
          sopsFile = ../../secrets/hosts/rakku.yaml;
          mode = "0400";
        };

        # ai-gateway.service reads the ElevenLabs API key through LoadCredential.
        sops.secrets.elevenlabs-api-key = {
          sopsFile = ../../secrets/hosts/rakku.yaml;
          mode = "0400";
        };
        # No service reads the xAI API key yet.
        sops.secrets.xai-api-key = {
          sopsFile = ../../secrets/hosts/rakku.yaml;
          mode = "0400";
        };

        assertions = [
          {
            assertion = config.system.stateVersion == "24.11";
            message = "Rakku must retain its existing stateVersion.";
          }
          {
            assertion = config.services.home-assistant.package.version == "2025.12.3";
            message = "Rakku migration must not upgrade Home Assistant.";
          }
          {
            assertion = config.services.zwave-js.package.version == "3.4.0";
            message = "Rakku migration must not upgrade Z-Wave JS.";
          }
          {
            assertion = config.users.users.hass.uid == 286 && config.users.groups.hass.gid == 286;
            message = "Rakku must preserve Home Assistant ownership.";
          }
        ];
      };
  };
}
