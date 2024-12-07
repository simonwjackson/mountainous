{
  config,
  inputs,
  lib,
  modulesPath,
  pkgs,
  system,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disko.nix
    ./snowscape
  ];

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 0;
  };

  networking = {
    nat = {
      enable = true;
      internalInterfaces = ["ve-+"];
      externalInterface = "eno1";
    };

    firewall = {
      enable = true;
    };
  };

  systemd.tmpfiles.rules = [
    "d /snowscape 0775 media media -"
    "d /snowscape/audiobooks 0775 media media -"
    "d /snowscape/music 0775 media media -"
    "d /snowscape/podcasts 0775 media media -"
    "d /snowscape/videos 0775 media media -"
    "d /snowscape/books 0775 media media -"
    "d /snowscape/comics 0775 media media -"

    # Borg
    "d /avalanche/groups/local/snowscape/backup/gaming-profiles 0750 root root -"
    "d /avalanche/groups/local/snowscape/backup/notes 0750 root root -"
    "d /avalanche/groups/local/snowscape/backup/media-services 0750 root root -"
  ];

  containers = let
    fastestVpnPrivateKeyFile = config.age.secrets."fastestvpn".path;
    fastestVpnPublicKey = "658QxufMbjOTmB61Z7f+c7Rjg7oqWLnepTalqBERjF0=";
    fastestVpnEndpoint = "139.28.179.82:51820";

    proton0SoulseekPrivateKeyFile = config.age.secrets."proton-0-soulseek".path;
    protonAddress = "10.2.0.2/32";
    protonDns = "10.2.0.1";
    protonPort = 51820;

    tailscaleEphemeralAuthFile = config.age.secrets."tailscale-ephemeral".path;
    tailscaleMagicDns = "hummingbird-lake.ts.net";
    hostAddress = "192.168.100.1";
  in {
    #####
    # File Transfer
    #####

    soulseek = let
      slskdEnvFile = config.age.secrets."slskd_env".path;
    in {
      inherit hostAddress;
      localAddress = "192.168.100.50";
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "${tailscaleEphemeralAuthFile}".hostPath = tailscaleEphemeralAuthFile;
        "${slskdEnvFile}".hostPath = slskdEnvFile;
        "${proton0SoulseekPrivateKeyFile}".hostPath = proton0SoulseekPrivateKeyFile;
      };

      config = {...}: {
        system.stateVersion = "24.11";

        imports = [
          inputs.self.nixosModules.wg-killswitch
          inputs.self.nixosModules."networking/tailscaled"
        ];

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
            gateway = hostAddress;
            privateKeyFile = proton0SoulseekPrivateKeyFile;
            publicKey = "jqu/dcZfEtote0IN1H4ZFneR8p4sZ7juna+eUndhRgs=";
            server = "89.187.175.132";
            port = protonPort;
          };

          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = tailscaleEphemeralAuthFile;
              serve = 5030;
            };
          };
        };

        systemd.services.slskd = {
          serviceConfig = {
            UMask = "0002";
          };
        };

        services.slskd = {
          enable = true;
          user = "media";
          group = "media";
          environmentFile = slskdEnvFile;
          domain = null;
          settings.shares.directories = [];
        };

        users = {
          groups.media = {
            gid = lib.mkForce 333;
          };

          users.media = {
            home = "/var/lib/slskd";
            homeMode = "770";
            group = "media";
            uid = lib.mkForce 333;
            isNormalUser = false;
          };
        };
      };
    };

    usenet = let
      proton0UsenetPrivateKeyFile = config.age.secrets."proton-0-usenet".path;
      newsDemonUserFile = config.age.secrets."newsdemon-user".path;
      newsDemonPassFile = config.age.secrets."newsdemon-pass".path;
      apiKeyFile = config.age.secrets."sabnzbd-api-key".path;
      nzbKeyFile = config.age.secrets."sabnzbd-nzb-key".path;

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
        USER=$(${pkgs.coreutils}/bin/cat ${newsDemonUserFile})
        PASS=$(${pkgs.coreutils}/bin/cat ${newsDemonPassFile})
        API=$(${pkgs.coreutils}/bin/cat ${apiKeyFile})
        NZB=$(${pkgs.coreutils}/bin/cat ${nzbKeyFile})

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
      inherit hostAddress;

      localAddress = "192.168.100.11";
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "${tailscaleEphemeralAuthFile}" = {
          hostPath = tailscaleEphemeralAuthFile;
        };
        "${proton0UsenetPrivateKeyFile}" = {
          hostPath = proton0UsenetPrivateKeyFile;
        };
        "${newsDemonUserFile}" = {
          hostPath = newsDemonUserFile;
        };
        "${newsDemonPassFile}" = {
          hostPath = newsDemonPassFile;
        };
        "${apiKeyFile}" = {
          hostPath = apiKeyFile;
        };
        "${nzbKeyFile}" = {
          hostPath = nzbKeyFile;
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
            gateway = hostAddress;
            privateKeyFile = proton0UsenetPrivateKeyFile;
            publicKey = "IV0rNO3lSM0n0yEbCUtEwFnO0vPUbUNurIFnO6AxRhI=";
            server = "45.134.140.59";
            port = protonPort;
          };
          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = tailscaleEphemeralAuthFile;
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

    downloads = let
      privateKeyFile = config.age.secrets."proton-0-downloads".path;
      aria2RpcSecretFile = config.age.secrets."aria2-rpc-secret".path;
    in {
      inherit hostAddress;

      localAddress = "192.168.100.88";
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "${tailscaleEphemeralAuthFile}".hostPath = tailscaleEphemeralAuthFile;
        "${privateKeyFile}".hostPath = privateKeyFile;
        "${aria2RpcSecretFile}".hostPath = aria2RpcSecretFile;
      };

      config = {pkgs, ...}: {
        system.stateVersion = "24.11";

        imports = [
          ./aria2-custom.nix
          # ./ariaNg.nix
          # inputs.self.nixosModules.mylar3
          inputs.self.nixosModules.wg-killswitch
          inputs.self.nixosModules."networking/tailscaled"
        ];

        networking = {
          useHostResolvConf = false;
        };

        services.resolved = {
          enable = true;
          dnssec = "false";
        };

        mountainous = {
          # mylar3 = {
          #   enable = true;
          # };
          wg-killswitch = {
            inherit privateKeyFile;

            enable = true;
            name = "protonvpn";
            address = protonAddress;
            dns = protonDns;
            gateway = hostAddress;
            publicKey = "vsquyHHSbv76cOqCMZCREGur05Mp5XM0lbCAzrGDs2w=";
            server = "149.22.94.86";
          };
          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = tailscaleEphemeralAuthFile;
              serve = 8000;
            };
          };
        };

        boot.kernel.sysctl = {
          "net.core.rmem_max" = 4194304;
          "net.core.wmem_max" = 1048576;
        };

        # services.ariang = {
        #   enable = true;
        #   user = "media";
        #   group = "media";
        # };

        services.aria2-custom = {
          enable = true;
          user = "media";
          group = "media";
          rpcSecretFile = aria2RpcSecretFile;
          settings = {};
        };

        users = {
          groups.media = {
            gid = lib.mkForce 333;
          };

          users.media = {
            group = "media";
            uid = lib.mkForce 333;
          };
        };
      };
    };

    torrents = let
      privateKeyFile = config.age.secrets."proton-0-torrents".path;
    in {
      inherit hostAddress;

      localAddress = "192.168.100.77";
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "${tailscaleEphemeralAuthFile}".hostPath = tailscaleEphemeralAuthFile;
        "${privateKeyFile}".hostPath = privateKeyFile;
      };

      config = {pkgs, ...}: {
        system.stateVersion = "24.11";

        imports = [
          inputs.self.nixosModules.wg-killswitch
          inputs.self.nixosModules."networking/tailscaled"
        ];

        networking = {
          useHostResolvConf = false;
        };

        services.resolved = {
          enable = true;
          dnssec = "false";
        };

        mountainous = {
          wg-killswitch = {
            inherit privateKeyFile;

            enable = true;
            name = "protonvpn";
            address = protonAddress;
            dns = protonDns;
            gateway = hostAddress;
            publicKey = "KkUoHrIzkuQ4msZulqCFyRC1Gqcx8oMgbDFRn8wW1X8=";
            server = "95.173.221.65";
          };
          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = tailscaleEphemeralAuthFile;
              serve = 3000;
            };
          };
        };

        services.flood.enable = true;
        systemd.services.flood = {
          serviceConfig = {
            UMask = "0002";
            DynamicUser = lib.mkForce false;
            User = "media";
            Group = "media";
            StateDirectoryMode = "770";
          };
        };

        boot.kernel.sysctl = {
          "net.core.rmem_max" = 4194304;
          "net.core.wmem_max" = 1048576;
        };

        systemd.services.transmission.serviceConfig = {
          UMask = lib.mkForce "0002";
          # INFO: Needed to start without failure
          RootDirectory = lib.mkForce "";
          RootDirectoryStartOnly = lib.mkForce false;
          StateDirectoryMode = "770";
        };

        services.transmission = {
          enable = true;
          user = "media";
          group = "media";
          settings = {
            # Basic settings
            umask = 2;
            # Upload restrictions
            "speed-limit-up" = 1; # KB/s
            "speed-limit-up-enabled" = true;
            "upload-slots-per-torrent" = 1;
            # Ratio limits
            "ratio-limit" = 0;
            "ratio-limit-enabled" = true;
            "seedRatioLimit" = 0.0;
            "seedRatioLimited" = true;
            # Peer settings
            "peer-limit-per-torrent" = 10;
            # Queue settings
            "seed-queue-enabled" = false;
          };
        };

        users = {
          groups.media = {
            gid = lib.mkForce 333;
          };

          users.media = {
            group = "media";
            uid = lib.mkForce 333;
          };
        };
      };
    };

    index = let
      proton0IndexPrivateKeyFile = config.age.secrets."proton-0-index".path;
    in {
      inherit hostAddress;

      localAddress = "192.168.100.17";
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "${tailscaleEphemeralAuthFile}" = {
          hostPath = tailscaleEphemeralAuthFile;
          isReadOnly = true;
        };
        "${proton0IndexPrivateKeyFile}" = {
          hostPath = proton0IndexPrivateKeyFile;
          isReadOnly = true;
        };
      };

      config = {pkgs, ...}: {
        system.stateVersion = "24.11";

        imports = [
          inputs.self.nixosModules.wg-killswitch
          inputs.self.nixosModules."networking/tailscaled"
        ];

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
            gateway = hostAddress;
            privateKeyFile = proton0IndexPrivateKeyFile;
            publicKey = "ntBhUr1CJmbVydw6cgccMFGSzEcPugiikF/l4NuDygA=";
            server = "79.127.136.65";
            port = protonPort;
          };
          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = tailscaleEphemeralAuthFile;
              serve = 9696;
            };
          };
        };

        systemd.services.prowlarr = {
          serviceConfig = {
            UMask = "0002";
          };
        };

        services.prowlarr.enable = true;
        # services.flaresolverr.enable = true;
      };
    };

    ########
    # Apps
    ########

    search = let
      searxEnvFile = config.age.secrets."searx-env".path;
    in {
      inherit hostAddress;

      localAddress = "192.168.100.13";
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "${searxEnvFile}" = {
          hostPath = searxEnvFile;
          isReadOnly = true;
        };
        "${tailscaleEphemeralAuthFile}" = {
          hostPath = tailscaleEphemeralAuthFile;
          isReadOnly = true;
        };
      };

      config = {...}: {
        system.stateVersion = "24.11";

        imports = [
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
          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = tailscaleEphemeralAuthFile;
              serve = 8888;
            };
          };
        };

        services.searx = {
          enable = true;
          redisCreateLocally = true;
          environmentFile = config.age.secrets."searx-env".path;
          settings.server = {
            bind_address = "0.0.0.0";
            port = 8888;
            secret_key = "@SEARX_SECRET_KEY@";
          };
        };
      };
    };

    series = {
      inherit hostAddress;

      localAddress = "192.168.100.15";
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "${tailscaleEphemeralAuthFile}" = {
          hostPath = tailscaleEphemeralAuthFile;
          isReadOnly = true;
        };
        "/snowscape/videos/series" = {
          hostPath = "/snowscape/videos/series";
          isReadOnly = false;
        };
        "/var/lib/sabnzbd/Downloads/complete" = {
          hostPath = "/var/lib/nixos-containers/usenet/var/lib/sabnzbd/Downloads/complete";
          isReadOnly = false;
        };
        "/var/lib/transmission/Downloads" = {
          hostPath = "/var/lib/nixos-containers/torrents/var/lib/transmission/Downloads";
          isReadOnly = false;
        };
      };

      config = {...}: {
        system.stateVersion = "24.11";

        imports = [
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
          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = tailscaleEphemeralAuthFile;
              serve = 8989;
            };
          };
        };

        nixpkgs.config.permittedInsecurePackages = [
          "aspnetcore-runtime-6.0.36"
          "aspnetcore-runtime-wrapped-6.0.36"
          "dotnet-sdk-wrapped-6.0.428"
          "dotnet-sdk-6.0.428"
        ];

        services.sonarr = {
          enable = true;
          user = "media";
          group = "media";
        };

        users = {
          groups.media = {
            gid = lib.mkForce 333;
          };

          users.media = {
            home = "/var/lib/sonarr";
            homeMode = "770";
            group = "media";
            uid = lib.mkForce 333;
            isNormalUser = false;
          };
        };
      };
    };

    watch = {
      inherit hostAddress;

      localAddress = "192.168.100.18";
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "${tailscaleEphemeralAuthFile}" = {
          hostPath = tailscaleEphemeralAuthFile;
          isReadOnly = true;
        };
        "/snowscape/music/albums" = {
          hostPath = "/snowscape/music/albums";
          isReadOnly = false;
        };
        "/snowscape/videos" = {
          hostPath = "/snowscape/videos";
          isReadOnly = false;
        };
      };

      config = {...}: {
        system.stateVersion = "24.11";

        imports = [
          inputs.self.nixosModules."networking/tailscaled"
        ];

        networking = {
          useHostResolvConf = false;
        };

        services.resolved = {
          enable = true;
          dnssec = "false";
        };

        services.jellyfin = {
          enable = true;
          user = "media";
          group = "media";
        };

        systemd.services.jellyfin = {
          serviceConfig = {
            LimitNOFILE = 65536;
          };
        };

        boot.kernel.sysctl = {
          "fs.inotify.max_user_watches" = 524288;
        };

        users = {
          groups.media = {
            gid = lib.mkForce 333;
          };

          users.media = {
            home = "/var/lib/jellyfin";
            homeMode = "770";
            group = "media";
            uid = lib.mkForce 333;
            isNormalUser = false;
          };
        };

        mountainous = {
          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = tailscaleEphemeralAuthFile;
              serve = 8096;
            };
          };
        };
      };
    };

    films = {
      inherit hostAddress;

      localAddress = "192.168.100.16";
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "${tailscaleEphemeralAuthFile}" = {
          hostPath = tailscaleEphemeralAuthFile;
          isReadOnly = true;
        };
        "/snowscape/videos/films" = {
          hostPath = "/snowscape/videos/films";
          isReadOnly = false;
        };
        "/var/lib/sabnzbd/Downloads/complete" = {
          hostPath = "/var/lib/nixos-containers/usenet/var/lib/sabnzbd/Downloads/complete";
          isReadOnly = false;
        };
        "/var/lib/transmission/Downloads" = {
          hostPath = "/var/lib/nixos-containers/torrents/var/lib/transmission/Downloads";
          isReadOnly = false;
        };
      };

      config = {...}: {
        system.stateVersion = "24.11";

        imports = [
          inputs.self.nixosModules."networking/tailscaled"
        ];

        networking = {
          useHostResolvConf = false;
        };

        services.resolved = {
          enable = true;
          dnssec = "false";
        };

        mountainous = {
          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = tailscaleEphemeralAuthFile;
              serve = 7878;
            };
          };
        };

        users = {
          groups.media = {
            gid = lib.mkForce 333;
          };

          users.media = {
            home = "/var/lib/radarr";
            homeMode = "770";
            group = "media";
            uid = lib.mkForce 333;
            isNormalUser = false;
          };
        };

        services.radarr = {
          enable = true;
          user = "media";
          group = "media";
        };
      };
    };

    music = {
      inherit hostAddress;

      localAddress = "192.168.100.14";
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "${tailscaleEphemeralAuthFile}" = {
          hostPath = tailscaleEphemeralAuthFile;
          isReadOnly = true;
        };
      };

      config = {...}: {
        system.stateVersion = "24.11";

        imports = [
          inputs.self.nixosModules."networking/tailscaled"
          ./resonance.nix
        ];

        services.resonance = {
          enable = true;
          package = inputs.resonance.packages.${system}.resonance;

          # port = 5000;
          # dataDir = "/var/lib/resonance";
          # openFirewall = true;
        };

        networking = {
          useHostResolvConf = false; # Don't use host's resolv.conf
        };

        services.resolved = {
          enable = true;
          dnssec = "false";
        };

        mountainous = {
          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = tailscaleEphemeralAuthFile;
              serve = 5000;
            };
          };
        };

        users = {
          groups.media = {
            gid = lib.mkForce 333;
          };

          users.media = {
            homeMode = "770";
            group = "media";
            uid = lib.mkForce 333;
            isNormalUser = false;
          };
        };
      };
    };

    listen = {
      inherit hostAddress;

      localAddress = "192.168.100.20";
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "/snowscape/podcasts" = {
          hostPath = "/snowscape/podcasts";
          isReadOnly = false;
        };
        "/snowscape/audiobooks" = {
          hostPath = "/snowscape/audiobooks";
          isReadOnly = false;
        };
        "${tailscaleEphemeralAuthFile}" = {
          hostPath = tailscaleEphemeralAuthFile;
          isReadOnly = true;
        };
      };

      config = {...}: {
        system.stateVersion = "24.11";

        imports = [
          inputs.self.nixosModules."networking/tailscaled"
        ];

        services.audiobookshelf = {
          enable = true;
          user = "media";
          group = "media";
        };

        networking = {
          useHostResolvConf = false; # Don't use host's resolv.conf
        };

        services.resolved = {
          enable = true;
          dnssec = "false";
        };

        mountainous = {
          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = tailscaleEphemeralAuthFile;
              serve = 8000;
            };
          };
        };

        users = {
          groups.media = {
            gid = lib.mkForce 333;
          };

          users.media = {
            isSystemUser = false;
            homeMode = "770";
            group = "media";
            uid = lib.mkForce 333;
          };
        };
      };
    };

    notify = {
      inherit hostAddress;

      localAddress = "192.168.100.10";
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "${tailscaleEphemeralAuthFile}" = {
          hostPath = tailscaleEphemeralAuthFile;
          isReadOnly = true;
        };
      };

      config = {...}: let
        port = 8080;
      in {
        system.stateVersion = "24.11";

        imports = [
          inputs.self.nixosModules."networking/tailscaled"
        ];

        networking = {
          useHostResolvConf = false; # Don't use host's resolv.conf
        };

        services.resolved = {
          enable = true;
          dnssec = "false";
        };

        services.ntfy-sh = {
          enable = true;
          settings = {
            listen-http = ":${builtins.toString port}";
            base-url = "https://notify.${tailscaleMagicDns}";
          };
        };

        mountainous = {
          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = tailscaleEphemeralAuthFile;
              serve = port;
            };
          };
        };
      };
    };

    read = let
      kavitaTokenFile = config.age.secrets."kavita".path;
    in {
      inherit hostAddress;

      localAddress = "192.168.100.21";
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "/snowscape/books" = {
          hostPath = "/snowscape/books";
          isReadOnly = false;
        };
        "/snowscape/comics" = {
          hostPath = "/snowscape/comics";
          isReadOnly = false;
        };
        "${kavitaTokenFile}" = {
          hostPath = kavitaTokenFile;
          isReadOnly = true;
        };
        "${tailscaleEphemeralAuthFile}" = {
          hostPath = tailscaleEphemeralAuthFile;
          isReadOnly = true;
        };
      };

      config = {...}: {
        system.stateVersion = "24.11";

        imports = [
          inputs.self.nixosModules."networking/tailscaled"
        ];

        services.kavita = {
          enable = true;
          user = "media";
          tokenKeyFile = kavitaTokenFile;
        };

        networking = {
          useHostResolvConf = false; # Don't use host's resolv.conf
        };

        services.resolved = {
          enable = true;
          dnssec = "false";
        };

        mountainous = {
          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = tailscaleEphemeralAuthFile;
              serve = 5000;
            };
          };
        };

        users = {
          groups.media = {
            gid = lib.mkForce 333;
          };

          users.media = {
            homeMode = "770";
            group = "media";
            uid = lib.mkForce 333;
          };
        };
      };
    };
  };

  # backpacker = {
  #   performance.enable = true;
  #   profiles.laptop.enable = true;
  #   hardware.cpu.type = "intel";
  #   networking.core.names = [
  #     {
  #       name = "eth-primary";
  #       mac = "70:85:c2:c3:ff:09";
  #     }
  #     {
  #       name = "eth-secondary";
  #       mac = "00:e0:4c:68:01:39";
  #     }
  #   ];
  # };
  #
  # services.gamerack = {
  #   enable = true;
  #   database = "/glacier/snowscape/gaming/profiles/simonwjackson/games.yaml";
  #   environmentFiles = [
  #     config.age.secrets.game-collection-sync.path
  #   ];
  #   environment = {
  #     STEAM_ID = "76561198041190539";
  #     MOBY_USERNAME = "simonwjackson";
  #     MOBY_COLLECTION_ID = "333655";
  #     MOBY_COOKIE_FILE = "/tmp/mobygames-cookie.txt";
  #   };
  # };
  #

  # services.samba-wsdd.enable = true; # make shares visible for windows 10 clients
  # services.samba = {
  #   enable = true;
  #   securityType = "user";
  #   extraConfig = ''
  #     workgroup = MOUNTAINOUS
  #     server string = unzen
  #     netbios name = unzen
  #     security = user
  #     #use sendfile = yes
  #     #max protocol = smb2
  #     # note: localhost is the ipv6 localhost ::1
  #     hosts allow = 100. 192.18. 10.147.19. 127.0.0.1 localhost
  #     hosts deny = 0.0.0.0/0
  #     guest account = nobody
  #     map to guest = bad user
  #     acl allow execute always = True
  #   '';
  #   shares = {
  #     snowscape = {
  #       path = "/glacier/snowscape";
  #       browseable = "yes";
  #       "read only" = "no";
  #       "guest ok" = "yes";
  #       "create mask" = "0644";
  #       "directory mask" = "0755";
  #       "force user" = "simonwjackson";
  #       "force group" = "users";
  #     };
  #   };
  # };
  #

  services.borgbackup.jobs = {
    gaming-profiles = {
      paths = "/snowscape/gaming/profiles";
      repo = "/avalanche/groups/local/snowscape/backup/gaming-profiles";
      encryption.mode = "none";
      compression = "zstd,3";
      startAt = "*:0/5";
      exclude = [];
      prune = {
        keep = {
          within = "1d"; # Keep all within 1 day
          daily = 7; # Keep 7 daily backups
          weekly = 4; # Keep 4 weekly backups
          monthly = 6; # Keep 6 monthly backups
          yearly = 1; # Keep 1 yearly backup
        };
      };
    };

    media-services = {
      paths = [
        "/var/lib/nixos-containers/series/var/lib/sonarr"
        "/var/lib/nixos-containers/films/var/lib/radarr"
        "/var/lib/nixos-containers/index/var/lib/prowlarr"
        "/var/lib/nixos-containers/watch/var/lib/jellyfin"
      ];
      repo = "/avalanche/groups/local/snowscape/backup/media-services";
      encryption.mode = "none";
      compression = "lz4";
      startAt = "daily";
      exclude = [
        # Jellyfin excludes
        "**/jellyfin/log/*"
        "**/jellyfin/data/cache*"
        "**/jellyfin/data/transcoding-temp"
        "**/jellyfin/.aspnet"
        "**/jellyfin/plugins"
        "**/jellyfin/root"
        "**/jellyfin/Subtitle Edit"

        # Common patterns across *arr services
        "**/asp/**" # ASP.NET temporary files
        "**/logs/**" # Log directories
        "**/logs.db*" # Log database files
        "**/*.pid" # Process ID files
        "**/Sentry/**" # Sentry crash reporting
        "**/*db-shm" # SQLite shared memory files
        "**/*db-wal" # SQLite write-ahead logs
        "**/MediaCover/**" # Can be regenerated from metadata
      ];
      prune = {
        keep = {
          daily = 7;
          weekly = 4;
          monthly = 6;
          yearly = 2;
        };
      };
    };

    notes = {
      paths = "/snowscape/notes";
      repo = "/avalanche/groups/local/snowscape/backup/notes";
      encryption.mode = "none";
      compression = "zstd,3";
      startAt = "*:0/5";
      exclude = [];
      prune = {
        keep = {
          within = "1d"; # Keep all within 1 day
          daily = 7; # Keep 7 daily backups
          weekly = 4; # Keep 4 weekly backups
          monthly = 6; # Keep 6 monthly backups
          yearly = 1; # Keep 1 yearly backup
        };
      };
    };
  };

  services.syncthing = {
    enable = true;
    key = config.age.secrets.unzen-syncthing-key.path;
    cert = config.age.secrets.unzen-syncthing-cert.path;
  };

  services.printing.enable = true;
  services.printing.drivers = with pkgs; [brlaser];

  # Enable automatic discovery of the printer from other Linux systems with avahi running. services.avahi.enable = true;
  services.avahi.publish.enable = true;
  services.avahi.publish.userServices = true;
  services.printing.browsing = true;
  services.printing.listenAddresses = ["*:631"]; # Not 100% sure this is needed and you might want to restrict to the local network
  services.printing.allowFrom = ["all"]; # this gives access to anyone on the interface you might want to limit it see the official documentation
  services.printing.defaultShared = true; # If you want

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.useDHCP = lib.mkDefault true;

  # Enable SMART monitoring
  services.smartd = {
    enable = true;
    autodetect = true; # Monitor all devices that support SMART
    notifications = {
      mail.enable = true;
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  system.stateVersion = "23.05"; # Did you read the comment?
}
