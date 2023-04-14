{ pkgs, lib, ... }:

{
  imports = [
    ../modules/syncthing.nix
  ];

  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/472d17fc-6e31-4af2-8e9c-064fcfdce3ed";
      fsType = "ext4";
    };

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  networking.hostName = "unzen"; # Define your hostname.

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Chicago";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.utf8";

  # Configure keymap in X11
  services.xserver = {
    layout = "us";
    xkbVariant = "";
  };

  users.users.simonwjackson = {
    isNormalUser = true;
    description = "simonwjackson";
    extraGroups = [ "docker" "networkmanager" "wheel" ];
    packages = with pkgs; [
      beets
    ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    neovim
    git
    tmux

    fuse3 # for nofail option on mergerfs (fuse defaults to fuse2)
    mergerfs
    mergerfs-tools
    nfs-utils

    tailscale
  ];

  systemd.services.ensureNzbgetDownloadDir = {
    script = ''
      install -d -o simonwjackson -g users -m 770 /tank/downloads/nzbget
    '';
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
    };
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  networking.firewall.enable = false;
  networking.firewall.allowPing = true;
  services.samba.openFirewall = true;

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    5357 # wsdd
    22 # SSH
    111
    2049
    4000
    4001
    4002
    20048 # NFS
  ];
  networking.firewall.allowedUDPPorts = [
    3702 # wsdd
    111
    2049
    4000
    4001
    4002
    20048 # NFS
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.05"; # Did you read the comment?


  services.jellyfin.enable = true;

  services.tailscale.enable = true;

  systemd.services.tailscale-autoconnect = {
    description = "Automatic connection to Tailscale";

    # make sure tailscale is running before trying to connect to tailscale
    after = [ "network-pre.target" "tailscale.service" ];
    wants = [ "network-pre.target" "tailscale.service" ];
    wantedBy = [ "multi-user.target" ];

    # set this service as a oneshot job
    serviceConfig.Type = "oneshot";

    # have the job run this shell script
    script = with pkgs; ''
      # wait for tailscaled to settle
            sleep 2

      # check if we are already authenticated to tailscale
            status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
            if [ $status = "Running" ]; then # if so, then do nothing
              exit 0
                fi

      # otherwise authenticate with tailscale
                ${tailscale}/bin/tailscale up -authkey tskey-auth-k9fj4d6CNTRL-MtbBSeRNVw3Q1bWpJKtjs3zE5j19PCMc
    '';
  };

  programs.mosh.enable = true;

  services.nzbget = {
    enable = true;
    group = "users";
    user = "simonwjackson";
    settings = {
      MainDir = "/tank/downloads/nzbget";
      DestDir = "/tank/downloads/nzbget/complete";
      InterDir = "/tank/downloads/nzbget/incomplete";
      NzbDir = "/tank/downloads/nzbget/nzb";
      QueueDir = "/tank/downloads/nzbget/queue";
      TempDir = "/tank/downloads/nzbget/tmp";

      ##############################################################################
      ### NEWS-SERVERS                                                           ###

      # This section defines which servers NZBGet should connect to.
      #
      # The servers should be numbered subsequently without holes.
      # For example if you configure three servers you should name them as Server1,
      # Server2 and Server3. If you need to delete Server2 later you should also
      # change the name of Server3 to Server2. Otherwise it will not be properly
      # read from the config file. Server number doesn't affect its priority (level).

      # Use this news server (yes, no).
      #
      # Set to "no" to disable the server on program start. Servers can be activated
      # later via scheduler tasks or manually via web-interface.
      #
      # NOTE: Download is not possible when all servers on level 0 are disabled. Servers
      # on higher levels are used only if at least one server on level 0 was tried.
      "Server1.Active" = false;

      # Name of news server.
      #
      # The name is used in UI and for logging. It can be any string, you
      # may even leave it empty.
      "Server1.Name" = "News Demon";

      # Level (priority) of news server (0-99).
      #
      # The servers are ordered by their level. NZBGet first tries to download
      # an article from one (any) of level-0-servers. If that server fails,
      # NZBGet tries all other level-0-servers. If all servers fail, it proceeds
      # with the level-1-servers, etc.
      #
      # Put your major download servers at level 0 and your fill servers at
      # levels 1, 2, etc..
      #
      # Several servers with the same level may be defined, they have
      # the same priority.
      "Server1.Level" = 1;

      # This is an optional non-reliable server (yes, no).
      #
      # Marking server as optional tells NZBGet to ignore this server if a
      # connection to this server cannot be established. Normally NZBGet
      # doesn't try upper-level servers before all servers on current level
      # were tried. If a connection to server fails NZBGet waits until the
      # server becomes available (it may try others from current level at this
      # time). This is usually what you want to avoid exhausting of
      # (costly) upper level servers if one of main servers is temporary
      # unavailable. However, for less reliable servers you may prefer to ignore
      # connection errors and go on with higher-level servers instead.
      "Server1.Optional" = false;

      # Group of news server (0-99).
      #
      # If you have multiple accounts with same conditions (retention, etc.)
      # on the same news server, set the same group (greater than 0) for all
      # of them. If download fails on one news server, NZBGet does not try
      # other servers from the same group.
      #
      # Value "0" means no group defined (default).
      "Server1.Group" = 0;

      # Host name of news server.
      "Server1.Host" = "us.newsdemon.com";

      # Port to connect to (1-65535).
      "Server1.Port" = 80;

      # User name to use for authentication.
      "Server1.Username" = builtins.getEnv "NEWS_DEMON_USERNAME";

      # Password to use for authentication.
      "Server1.Password" = builtins.getEnv "NEWS_DEMON_PASSWORD";

      # Server requires "Join Group"-command (yes, no).
      "Server1.JoinGroup" = false;

      # Encrypted server connection (TLS/SSL) (yes, no).
      #
      # NOTE: By changing this option you should also change the option <ServerX.Port>
      # accordingly because unsecure and encrypted connections use different ports.
      "Server1.Encryption" = true;

      # # Cipher to use for encrypted server connection.
      # #
      # # By default (when the option is empty) the underlying encryption library
      # # chooses the cipher automatically. To achieve the best performance
      # # however you can manually select a faster cipher.
      # #
      # # See http://nzbget.net/choosing-cipher for details.
      # #
      # # NOTE: You may get a TLS handshake error if the news server does
      # # not support the chosen cipher. You can also get an error "Could not
      # # select cipher for TLS" if the cipher string is not valid.
      # Server1.Cipher=

      # Maximum number of simultaneous connections to this server (0-999).
      "Server1.Connections" = 20;

      # Server retention time (days).

      # How long the articles are stored on the news server. The articles
      # whose age exceed the defined server retention time are not tried on
      # this news server, the articles are instead considered failed on this
      # news server.

      # Value "0" disables retention check.
      "Server1.Retention" = 3000;

      # IP protocol version (auto, ipv4, ipv6).
      "Server1.IpVersion" = "auto";






      "Server2.Active" = true;
      "Server2.Name" = "eweka";
      "Server2.Level" = 0;
      "Server2.Optional" = false;
      "Server2.Group" = 0;
      "Server2.Host" = "news.eweka.nl";
      "Server2.Port" = 563;
      "Server2.Username" = builtins.getEnv "EWEKA_USERNAME";
      "Server2.Password" = builtins.getEnv "EWEKA_PASSWORD";
      "Server2.JoinGroup" = false;
      "Server2.Encryption" = true;
      "Server2.Connections" = 20;
      "Server2.Retention" = 5278;
      "Server2.IpVersion" = "auto";

    };
  };

  fileSystems = {
    #"/run/media/parity/scsi1" = {
    #  device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi1-part1";
    #};

    #"/run/media/parity/scsi2" = {
    #  device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi2-part1";
    #};

    "/run/media/pool/scsi3" = {
      device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi3-part1";
    };

    "/run/media/pool/scsi4" = {
      device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi4-part1";
    };

    "/run/media/pool/scsi5" = {
      device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi5-part1";
    };

    "/run/media/pool/scsi6" = {
      device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi6-part1";
    };

    # mergerfs: merge drives
    "/tank" = {
      device = "/run/media/pool/scsi3:/run/media/pool/scsi4:/run/media/pool/scsi5:/run/media/pool/scsi6";
      fsType = "fuse.mergerfs";
      options = [
        "defaults"
        "allow_other"
        "use_ino"
        "cache.files=partial"
        "dropcacheonclose=true"
        "category.create=epff"
        "nofail"
      ];
    };
  };

  services.autofs.enable = true;
  services.autofs.autoMaster = ''
    /net -hosts --timeout=60
  '';

  services.nfs.server = {
    enable = true;
    exports = ''
      /tank  192.18.0.0/16(rw,fsid=0,sync,crossmnt)
    '';
    # fixed rpc.statd port; for firewall
    # lockdPort = 4001;
    # mountdPort = 4002;
    # statdPort = 4000;
    # extraNfsdConfig = '''';
  };


  services.samba-wsdd.enable = true; # make shares visible for windows 10 clients
  services.samba = {
    enable = true;
    securityType = "user";
    extraConfig = ''
      workgroup = WORKGROUP
      server string = smbnix
      netbios name = smbnix
      security = user
      #use sendfile = yes
      #max protocol = smb2
      # note: localhost is the ipv6 localhost ::1
      hosts allow = 100. 192.18. 127.0.0.1 localhost
      hosts deny = 0.0.0.0/0
      guest account = nobody
      map to guest = bad user
      acl allow execute always = True
    '';
    shares = {
      storage = {
        path = "/tank";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "simonwjackson";
        "force group" = "users";
      };
    };
  };

  services.slskd.enable = true;

  virtualisation = {
    podman = {
      enable = true;

      # Create a `docker` alias for podman, to use it as a drop-in replacement
      dockerCompat = true;

      # Required for containers under podman-compose to be able to talk to each other.
      # defaultNetwork.dnsname.enable = true;

      defaultNetwork.settings.dns_enabled = true;
    };
    oci-containers = {
      backend = "podman";
      containers = {
        # TODO: ensure directorys exists before running

        # TODO: Need to setup taskwarrior locally first
        # taskwarrior-web = {
        #   autoStart = true;
        #   image = "dcsunset/taskwarrior-webui";
        #   ports = [ "0.0.0.0:8080:80" ];
        #   environment = {
        #     TAKSRC="$HOME/.taskrc";
        #     TASKDATA="$HOME/.task";
        #   };
        #   volumes = [
        #     "/home/simonwjackson/.taskrc:$HOME/.taskrc"
        #     "/home/simonwjackson/.task:$HOME/.task"
        #   ];
        # };

        jackett = {
          autoStart = true;
          image = "lscr.io/linuxserver/jackett:latest";
          ports = [ "0.0.0.0:9117:9117" ];
          environment = {
            PUID = "1000";
            PGID = "1000";
            TZ = "America/Chicago";
          };
          volumes = [
            "/tank/configs/jackett:/config"
            "/tank/downloads/torrents:/downloads"
          ];
        };

        navidrome = {
          autoStart = true;
          image = "deluan/navidrome:latest";
          user = "1000:1000";
          ports = [ "0.0.0.0:4533:4533" ];
          environment = { };
          volumes = [
            "/tank/configs/navidrome:/data"
            "/tank/music:/music:ro"
          ];
        };

        #code-server = {
        #  image="lscr.io/linuxserver/code-server:latest";
        #  environment = {
        #   PUID="1000";
        #   PGID="1000";
        #   TZ="Etc/UTC";
        #  };
        #  volumes = [
        #    "/tank/config/vscode/config"
        #    "/tank/code:/code"
        #  ];
        #  ports = [ "0.0.0.0:8443:8443" ];
        #};

        gpt_chat = {
          image = "ghcr.io/cogentapps/chat-with-gpt:release";
          ports = [ "0.0.0.0:3000:3000" ];
          volumes = [
            "/etc/localtime:/etc/localtime:ro"
            "/tank/gpt:/app/data"
          ];
        };

        sonarr = {
          autoStart = true;
          image = "lscr.io/linuxserver/sonarr:latest";
          ports = [ "0.0.0.0:8989:8989" ];
          environment = {
            PUID = "1000";
            PGID = "100";
            TZ = "America/Chicago";
          };
          volumes = [
            "/tank/configs/sonnar:/config"
            "/tank/series:/tv"
            "/tank/downloads:/tank/downloads"
          ];
        };

        nzbhydra2 = {
          autoStart = true;
          image = "lscr.io/linuxserver/nzbhydra2:latest";
          ports = [ "0.0.0.0:5076:5076" ];
          environment = {
            PUID = "1000";
            PGID = "100";
            TZ = "America/Chicago";
          };
          volumes = [
            "/tank/configs/nzbhydra2:/config"
            "/tank/downloads/nzbhydra2:/downloads"
          ];
        };

        rss-proxy = {
          autoStart = true;
          image = "damoeb/rss-proxy:latest";
          ports = [ "8889:3000" ];
        };

        fivefilters-full-text-rss = {
          autoStart = true;
          image = "heussd/fivefilters-full-text-rss:latest";
          ports = [ "8888:80" ];
          volumes = [
            "rss-cache:/var/www/html/cache"
          ];
          environment = {
            FTR_ADMIN_PASSWORD = "";
          };
        };
      };
    };
  };

  services.taskserver = {
    enable = true;
    fqdn = "unzen";
    listenHost = "::";
    organisations.mountainous.users = [ "simonwjackson" ];
  };

  services.syncthing = {
    dataDir = "/tank"; # Default folder for new synced folders
    extraFlags = [
      "-gui-address=0.0.0.0:8384"
    ];

    folders = {
      documents.path = "/tank/documents";
      audiobooks.path = "/tank/audiobooks";
      books.path = "/tank/books";
      gaming-profiles-simonwjackson.path = "/tank/gaming/profiles/simonwjackson";
      music.path = "/tank/music";
      code.path = "/tank/code";
    };
  };
}
