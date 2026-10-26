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
      "notify-server"
      "beszel-hub"
      "pi-assistant"
      "signal-responder"
      "vela"
      "no-builds"
    ];
    module =
      { config, lib, ... }:
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
          people = {
            simon = {
              voicePort = 4317;
              webPort = 4318;
              # Simon's assistant clones, pushes, and opens pull requests as him.
              github = true;
              skills.scryer = "/nix/var/nix/profiles/per-user/pi-assistant/skills/scryer";
              credentials.scryer-admin-password = config.sops.secrets.scryer-admin-password.path;
              # The household decision gateway (modules/decision-gateway.nix): core's
              # reflexes, thread choice and recall ask Jev through it (assistant ADR 0001).
              credentials.decide-api-key = config.sops.secrets.pi-decide-api-key.path;
            };
            laure = {
              voicePort = 4327;
              webPort = 4328;
              skills.scryer = "/nix/var/nix/profiles/per-user/pi-assistant/skills/scryer";
              credentials.scryer-admin-password = config.sops.secrets.scryer-admin-password.path;
              # The household decision gateway (modules/decision-gateway.nix): core's
              # reflexes, thread choice and recall ask Jev through it (assistant ADR 0001).
              credentials.decide-api-key = config.sops.secrets.pi-decide-api-key.path;
            };
          };
          household = {
            skills.scryer = "/nix/var/nix/profiles/per-user/pi-assistant/skills/scryer";
            credentials.scryer-admin-password = config.sops.secrets.scryer-admin-password.path;
            # The household decision gateway (modules/decision-gateway.nix): core's
            # reflexes, thread choice and recall ask Jev through it (assistant ADR 0001).
            credentials.decide-api-key = config.sops.secrets.pi-decide-api-key.path;
          };
          tailnet = "hummingbird-lake.ts.net";
          # Vela's /surface link (Vela ADR 0007).
          extraWebOrigins = [ config.mountainous.features.vela.origin ];
          homePlace = "Denver|39.739|-104.985|America/Denver";
          cliproxyapiKeyFile = config.sops.secrets.pi-assistant-cliproxyapi-key.path;
          braveApiKeyFile = config.sops.secrets.pi-assistant-brave-api-key.path;
          # The groceries app on Zao (sandbox/groceries); its copy of the token is
          # ~/.config/groceries/assistant-service-token there.
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
