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
    "net.ipv6.conf.all.forwarding" = 1;
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
  ];

  containers = let
    fastestVpnPrivateKeyFile = config.age.secrets."fastestvpn".path;
    fastestVpnPublicKey = "658QxufMbjOTmB61Z7f+c7Rjg7oqWLnepTalqBERjF0=";
    fastestVpnEndpoint = "167.160.88.250:51820";
    tailscaleEphemeralAuthFile = config.age.secrets."tailscale-ephemeral".path;
    tailscaleMagicDns = "hummingbird-lake.ts.net";
    hostAddress = "192.168.100.1";
  in {
    soulseek = let
      slskdEnvFile = config.age.secrets."slskd_env".path;
      fastestVpnPrivateKeyFile = config.age.secrets."fastestvpn".path;
    in {
      inherit hostAddress;
      localAddress = "192.168.100.50";
      privateNetwork = true;
      autoStart = true;
      enableTun = true;

      bindMounts = {
        "${tailscaleEphemeralAuthFile}" = {
          hostPath = tailscaleEphemeralAuthFile;
          isReadOnly = true;
        };
        "${slskdEnvFile}" = {
          hostPath = slskdEnvFile;
          isReadOnly = true;
        };
        "${fastestVpnPrivateKeyFile}" = {
          hostPath = fastestVpnPrivateKeyFile;
          isReadOnly = true;
        };
      };

      config = {...}: {
        system.stateVersion = "24.11";

        imports = [
          inputs.self.nixosModules.container-fastest-vpn
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
          container-fastest-vpn = {
            enable = true;
            privateKeyFile = fastestVpnPrivateKeyFile;
            publicKey = fastestVpnPublicKey;
            endpoint = fastestVpnEndpoint;
            gateway = hostAddress;
          };

          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = tailscaleEphemeralAuthFile;
              serve = 5030;
            };
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
          isReadOnly = true;
        };
        "${fastestVpnPrivateKeyFile}" = {
          hostPath = fastestVpnPrivateKeyFile;
          isReadOnly = true;
        };
        "${newsDemonUserFile}" = {
          hostPath = newsDemonUserFile;
          isReadOnly = true;
        };
        "${newsDemonPassFile}" = {
          hostPath = newsDemonPassFile;
          isReadOnly = true;
        };
        "${apiKeyFile}" = {
          hostPath = apiKeyFile;
          isReadOnly = true;
        };
        "${nzbKeyFile}" = {
          hostPath = nzbKeyFile;
          isReadOnly = true;
        };
      };

      config = {pkgs, ...}: {
        system.stateVersion = "24.11";

        imports = [
          inputs.self.nixosModules.container-fastest-vpn
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
          container-fastest-vpn = {
            enable = true;
            privateKeyFile = fastestVpnPrivateKeyFile;
            publicKey = fastestVpnPublicKey;
            endpoint = fastestVpnEndpoint;
            gateway = hostAddress;
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

    search = {
      inherit hostAddress;

      localAddress = "192.168.100.13";
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
        "/snowscape/videos" = {
          hostPath = "/snowscape/videos";
          isReadOnly = false;
        };
      };

      config = {...}: {
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
      };

      config = {pkgs, ...}: {
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

    index = {
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
        "${fastestVpnPrivateKeyFile}" = {
          hostPath = fastestVpnPrivateKeyFile;
          isReadOnly = true;
        };
      };

      config = {pkgs, ...}: {
        system.stateVersion = "24.11";

        imports = [
          inputs.self.nixosModules.container-fastest-vpn
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
          container-fastest-vpn = {
            enable = true;
            privateKeyFile = fastestVpnPrivateKeyFile;
            publicKey = fastestVpnPublicKey;
            endpoint = fastestVpnEndpoint;
            gateway = hostAddress;
          };
          networking = {
            tailscaled = {
              enable = true;
              authKeyFile = tailscaleEphemeralAuthFile;
              serve = 9696;
            };
          };
        };

        services.prowlarr.enable = true;
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
  #     workgroup = WORKGROUP
  #     server string = smbnix
  #     netbios name = smbnix
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
  # services.borgbackup.jobs = {
  #   taskwarrior = {
  #     paths = "/home/simonwjackson/.local/share/task";
  #     repo = "/glacier/iceberg/permafrost/taskwarrior";
  #     encryption.mode = "none";
  #     compression = "zstd,22";
  #     startAt = "hourly";
  #     prune = {
  #       keep = {
  #         within = "7d";
  #       };
  #     };
  #   };
  #
  #   gaming-profiles = {
  #     paths = "/glacier/snowscape/gaming/profiles";
  #     repo = "/glacier/iceberg/permafrost/gaming/profiles";
  #     encryption.mode = "none";
  #     compression = "zstd,22";
  #     startAt = "daily"; # every day
  #     exclude = [];
  #     prune = {
  #       keep = {
  #         within = "30d";
  #       };
  #     };
  #   };
  #
  #   photos = {
  #     paths = "/glacier/snowscape/photos";
  #     repo = "/glacier/iceberg/permafrost/photos";
  #     encryption.mode = "none";
  #     compression = "zstd,22";
  #     startAt = "daily"; # every day
  #   };
  #
  #   notes = {
  #     paths = "/glacier/snowscape/documents/notes";
  #     repo = "/glacier/iceberg/permafrost/notes";
  #     encryption.mode = "none";
  #     startAt = "daily"; # every day
  #     prune = {
  #       keep = {
  #         within = "30d";
  #       };
  #     };
  #   };
  # };
  #
  # services.syncthing = {
  #   enable = true;
  #   key = config.age.secrets.unzen-syncthing-key.path;
  #   cert = config.age.secrets.unzen-syncthing-cert.path;
  # };

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
  networking.networkmanager.enable = true;

  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = ["wheel"]; # Enable ‘sudo’ for the user.
  };

  environment.systemPackages = with pkgs; [
    neovim
    git
    tmux
  ];

  services.openssh.enable = true;

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
      x11.enable = true;
      mail.enable = true;
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  system.stateVersion = "23.05"; # Did you read the comment?
}
