{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  inherit (lib.mountainous) enabled;

  cfg = config.mountainous.services.usenet;

  protonAddress = "10.2.0.2/32";
  protonDns = "10.2.0.1";
  protonPort = 51820;
  tailscaleMagicDns = "hummingbird-lake.ts.net";

  sabnzbdTemplateConfig = pkgs.writeTextFile {
    name = "sabnzbd-template.ini";
    text = import ./sabnzbd-config.nix {
      rootDir = "/var/lib/sabnzbd";
      hosts = [
        "usenet.${tailscaleMagicDns}"
        "usenet"
        "localhost"
      ];
    };
  };

  setupScript = pkgs.writeShellScript "setup-sabnzbd-config" ''
    ${pkgs.coreutils}/bin/set -euo pipefail

    ${pkgs.coreutils}/bin/echo "Starting SABnzbd config setup..."

    # Ensure directory exists
    ${pkgs.coreutils}/bin/mkdir -p /var/lib/sabnzbd

    # Debug: Check template file exists and has content
    ${pkgs.coreutils}/bin/echo "Template file path: ${sabnzbdTemplateConfig}"
    if [ ! -f "${sabnzbdTemplateConfig}" ]; then
      ${pkgs.coreutils}/bin/echo "Error: Template file not found!"
      ${pkgs.coreutils}/bin/exit 1
    fi

    # Debug: Check age secret files exist
    ${pkgs.coreutils}/bin/echo "Checking age secret files..."
    if [ ! -f "${config.age.secrets."newsdemon-user".path}" ]; then
      ${pkgs.coreutils}/bin/echo "Error: User secret file not found!"
      ${pkgs.coreutils}/bin/exit 1
    fi
    if [ ! -f "${config.age.secrets."newsdemon-pass".path}" ]; then
      ${pkgs.coreutils}/bin/echo "Error: Password secret file not found!"
      ${pkgs.coreutils}/bin/exit 1
    fi

    # Read credentials from age-encrypted files
    ${pkgs.coreutils}/bin/echo "Reading credentials..."
    USER=$(${pkgs.coreutils}/bin/cat ${config.age.secrets."newsdemon-user".path})
    PASS=$(${pkgs.coreutils}/bin/cat ${config.age.secrets."newsdemon-pass".path})
    API=$(${pkgs.coreutils}/bin/cat ${config.age.secrets."sabnzbd-api-key".path})
    NZB=$(${pkgs.coreutils}/bin/cat ${config.age.secrets."sabnzbd-nzb-key".path})

    # Debug: Check if credentials were read (length only, don't print values)
    ${pkgs.coreutils}/bin/echo "Credential lengths - User: ''${#USER}, Pass: ''${#PASS}"

    # Create final config with substituted credentials
    ${pkgs.coreutils}/bin/echo "Creating final config..."
    ${pkgs.gnused}/bin/sed \
      -e "s|@@NEWSDEMON_USER@@|$USER|g" \
      -e "s|@@NEWSDEMON_PASS@@|$PASS|g" \
      -e "s|@@API_KEY@@|$API|g" \
      -e "s|@@NZB_KEY@@|$NZB|g" \
      "${sabnzbdTemplateConfig}" > /var/lib/sabnzbd/sabnzbd.ini

    # Check if the file was created and has content
    if [ ! -s /var/lib/sabnzbd/sabnzbd.ini ]; then
      ${pkgs.coreutils}/bin/echo "Error: Generated config file is empty!"
      ${pkgs.coreutils}/bin/exit 1
    fi

    ${pkgs.coreutils}/bin/echo "Setting permissions..."
    # Set correct ownership and permissions
    ${pkgs.coreutils}/bin/chown sabnzbd:sabnzbd /var/lib/sabnzbd/sabnzbd.ini
    ${pkgs.coreutils}/bin/chmod 400 /var/lib/sabnzbd/sabnzbd.ini

    ${pkgs.coreutils}/bin/echo "SABnzbd config setup complete."
  '';
in {
  options.mountainous.services.usenet = {
    enable = mkEnableOption "Whether to enable";

    tailscaleAuthFile = mkOption {
      type = types.path;
      description = "Path to the Tailscale authentication file";
      default = config.age.secrets."tailscale-ephemeral".path;
    };

    address = {
      host = mkOption {
        type = types.str;
        description = "Host address for the container network";
      };

      client = mkOption {
        type = types.str;
        description = "Client address for the container network";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    containers.usenet = {
      hostAddress = cfg.address.host;
      localAddress = cfg.address.client;
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "${cfg.tailscaleAuthFile}" = {
          hostPath = cfg.tailscaleAuthFile;
        };
        "${config.age.secrets."proton-0-usenet".path}" = {
          hostPath = config.age.secrets."proton-0-usenet".path;
        };
        "${config.age.secrets."newsdemon-user".path}" = {
          hostPath = config.age.secrets."newsdemon-user".path;
        };
        "${config.age.secrets."newsdemon-pass".path}" = {
          hostPath = config.age.secrets."newsdemon-pass".path;
        };
        "${config.age.secrets."sabnzbd-api-key".path}" = {
          hostPath = config.age.secrets."sabnzbd-api-key".path;
        };
        "${config.age.secrets."sabnzbd-nzb-key".path}" = {
          hostPath = config.age.secrets."sabnzbd-nzb-key".path;
        };
      };

      config = {pkgs, ...}: {
        system.stateVersion = "24.11";

        imports = [
          inputs.self.nixosModules.wg-killswitch
          inputs.self.nixosModules."networking/tailscaled"
        ];

        nixpkgs.config.allowUnfree = true;

        networking = {
          useHostResolvConf = false;
        };

        services.resolved = {
          enable = true;
          dnssec = "false";
        };

        mountainous = {
          wg-killswitch = {
            enable = true;
            name = "protonvpn";
            address = protonAddress;
            dns = protonDns;
            gateway = cfg.address.host;
            privateKeyFile = config.age.secrets."proton-0-usenet".path;
            publicKey = "IV0rNO3lSM0n0yEbCUtEwFnO0vPUbUNurIFnO6AxRhI=";
            server = "45.134.140.59";
            port = protonPort;
          };
          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = cfg.tailscaleAuthFile;
              serve = 8080;
            };
          };
        };

        system.activationScripts.setupSabnzbd = {
          text = ''
            echo "Running SABnzbd setup activation script..."
            ${setupScript}
          '';
          deps = ["var" "users" "groups"];
        };

        systemd.services.sabnzbd = {
          serviceConfig = {
            UMask = "0002";
          };
        };

        services.sabnzbd = {
          enable = true;
          user = "media";
          group = "media";
        };

        users = {
          groups.media = {
            gid = lib.mkForce 333;
          };

          users.media = {
            home = "/var/lib/sabnzbd";
            homeMode = "770";
            group = "media";
            uid = lib.mkForce 333;
            isNormalUser = false;
          };
        };
      };
    };
  };
}
