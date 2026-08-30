{
  nixConfig = {
    warn-dirty = false;
  };

  description = "Mountainous — unified NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-droid.url = "github:NixOS/nixpkgs/nixos-24.05";
    nix-on-droid = {
      url = "github:nix-community/nix-on-droid/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs-droid";
    };
    dnshack = {
      url = "github:ettom/dnshack";
      flake = false;
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    impermanence.url = "github:nix-community/impermanence";
    gomod2nix = {
      url = "github:nix-community/gomod2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprdynamicmonitors = {
      url = "github:fiffeek/hyprdynamicmonitors";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flexget-webui = {
      url = "github:Flexget/webui";
      flake = false;
    };
    taskwarrior-recurrence = {
      url = "github:lyz-code/taskwarrior_recurrence";
      flake = false;
    };
    # Fuji-specific inputs
    tsnsrv = {
      url = "github:boinkor-net/tsnsrv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cascade = {
      url = "github:cascadefox/cascade";
      flake = false;
    };
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    jellyswarrm = {
      url = "github:LLukas22/Jellyswarrm/v0.2.1";
      flake = false;
    };
    korri = {
      url = "github:simonwjackson/korri";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Zao consumes the isolated Linux host profile without changing the Korri
    # revision used by Aka and Sobo.
    korri-input-host = {
      url = "github:simonwjackson/korri";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs-rpcs3-v0-0-41.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Lukas's unofficial Nix flake for pi (earendil-works/pi), the terminal
    # coding agent. Exposes a NixOS module under programs.pi.coding-agent
    # and a package via inputs.pi.packages.<system>.coding-agent. We wrap
    # both behind mountainous.features.pi so every host gets the binary
    # without leaking the upstream option path into host files.
    pi = {
      url = "github:lukasl-dev/pi.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # ROCKNIX-on-SM8550 NixOS guest. Owns the device schema (rocknix.sm8550),
    # the main-space profile, and the Odin 2 Portal device profile. We compose
    # those modules into nixosConfigurations.sobo below and expose the rootfs
    # tarball via packages.aarch64-linux.sobo-rootfs.
    nix-on-rocks-guest = {
      url = "github:simonwjackson/nix-on-rocks?dir=guest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-droid,
    nix-on-droid,
    disko,
    home-manager,
    agenix,
    nixos-hardware,
    impermanence,
    gomod2nix,
    hyprdynamicmonitors,
    nixos-anywhere,
    flexget-webui,
    taskwarrior-recurrence,
    tsnsrv,
    cascade,
    nixos-wsl,
    ...
  } @ inputs: let
    lib = nixpkgs.lib;
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];

    collectPackagePaths = prefix: dir: let
      entries = builtins.readDir dir;
      names = lib.sort (a: b: a < b) (builtins.attrNames entries);
    in
      lib.foldl' (
        acc: name: let
          type = entries.${name};
          path = dir + "/${name}";
          attrName =
            if prefix == ""
            then name
            else "${prefix}-${name}";
          current = lib.optionalAttrs (type == "directory" && builtins.pathExists (path + "/default.nix")) {
            "${attrName}" = path;
          };
          nested =
            if type == "directory"
            then collectPackagePaths attrName path
            else {};
        in
          acc // current // nested
      ) {}
      names;

    collectModulePaths = dir: let
      entries = builtins.readDir dir;
      names = lib.sort (a: b: a < b) (builtins.attrNames entries);
    in
      lib.concatMap (
        name: let
          type = entries.${name};
          path = dir + "/${name}";
        in
          if type != "directory"
          then []
          else lib.optional (builtins.pathExists (path + "/default.nix")) path ++ collectModulePaths path
      )
      names;

    collectPlatformModulePaths = dir: platformFile: let
      entries = builtins.readDir dir;
      names = lib.sort (a: b: a < b) (builtins.attrNames entries);
    in
      lib.concatMap (
        name: let
          type = entries.${name};
          path = dir + "/${name}";
          platformPath = path + "/${platformFile}";
          hasDefault = builtins.pathExists (path + "/default.nix");
          hasPlatform = type == "directory" && builtins.pathExists platformPath;
        in
          if hasPlatform
          then (lib.optional hasDefault path) ++ [platformPath]
          else if type == "directory"
          then collectPlatformModulePaths path platformFile
          else []
      )
      names;

    packagePaths = collectPackagePaths "" ./packages;
    # Keep non-derivation collections explicit. Filtering by isDerivation here
    # forces every package whenever Nix only needs the flake output names.
    derivationPackagePaths = builtins.removeAttrs packagePaths ["scripts"];
    nixosFeatureModulePaths = collectModulePaths ./features;
    nixosPresetModulePaths = collectModulePaths ./presets;
    droidFeatureModulePaths = collectPlatformModulePaths ./features "droid.nix";
    droidPresetModulePaths = collectPlatformModulePaths ./presets "droid.nix";

    packageOverlay = final: prev: let
      callPackage = lib.callPackageWith (final // {inherit inputs;});
    in
      lib.mapAttrs (_: path: callPackage path {}) derivationPackagePaths;

    extraOverlays = import ./overlays;
    projectOverlays = [packageOverlay] ++ extraOverlays;

    mkPkgs = system:
      import nixpkgs {
        inherit system;
        overlays = projectOverlays;
      };

    mkDroidPkgs = system:
      import nixpkgs-droid {
        inherit system;
        overlays = projectOverlays;
      };

    mkFlakePackages = system: let
      pkgs = mkPkgs system;
      callPackage = lib.callPackageWith (pkgs // {inherit inputs;});
    in
      lib.mapAttrs (_: path: callPackage path {}) derivationPackagePaths;

    mkHost = {
      system,
      hostPath,
      specialArgs ? {},
      extraModules ? [],
    }: let
      syncthingManifestPath = hostPath + "/syncthing.nix";
      syncthingManifest =
        if builtins.pathExists syncthingManifestPath
        then import syncthingManifestPath
        else null;
      # Host manifests are plain data. Keep the feature module as the schema
      # owner for runtime options by only forwarding option-shaped attrs here.
      hostAutoModules = lib.optional (syncthingManifest != null) {
        mountainous.features.syncthing =
          {
            enable = true;
          }
          // builtins.removeAttrs syncthingManifest ["deviceId"];
      };
    in
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs =
          {
            inherit
              self
              inputs
              cascade
              hyprdynamicmonitors
              tsnsrv
              ;
            mountainousPlatform = "nixos";
          }
          // specialArgs;
        modules =
          [
            disko.nixosModules.default
            agenix.nixosModules.default
            home-manager.nixosModules.home-manager
          ]
          ++ nixosFeatureModulePaths
          ++ nixosPresetModulePaths
          ++ [
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
            }
            (
              {lib, ...}: {
                nix.settings = {
                  experimental-features = [
                    "nix-command"
                    "flakes"
                  ];
                  trusted-users = [
                    "root"
                    "@wheel"
                    "simonwjackson"
                    "admin"
                  ];
                  warn-dirty = false;
                };
                users.users.simonwjackson.openssh.authorizedKeys.keyFiles = lib.mkDefault [
                  ./secrets/keys/users/id_rsa.pub
                  ./secrets/keys/users/id_ed25519.pub
                ];
                security.sudo.wheelNeedsPassword = lib.mkDefault false;
                networking.extraHosts = lib.mkDefault ''
                  127.0.0.1 amazesql01.database.windows.net
                  127.0.0.1 amazeportalsql.database.windows.net
                '';
                mountainous.features.tailscale.enable = lib.mkDefault true;
              }
            )
            {nixpkgs.overlays = projectOverlays;}
          ]
          ++ hostAutoModules
          ++ [hostPath]
          ++ extraModules;
      };

    mkDroidHost = {
      system ? "aarch64-linux",
      hostPath,
      specialArgs ? {},
      extraModules ? [],
    }: let
      syncthingManifestPath = hostPath + "/syncthing.nix";
      syncthingManifest =
        if builtins.pathExists syncthingManifestPath
        then import syncthingManifestPath
        else null;
      hostAutoModules = lib.optional (syncthingManifest != null) {
        mountainous.features.syncthing =
          {
            enable = true;
          }
          // builtins.removeAttrs syncthingManifest ["deviceId"];
      };
    in
      nix-on-droid.lib.nixOnDroidConfiguration {
        pkgs = mkDroidPkgs system;
        extraSpecialArgs =
          {
            inherit self inputs;
            mountainousPlatform = "droid";
          }
          // specialArgs;
        modules =
          droidFeatureModulePaths
          ++ droidPresetModulePaths
          ++ hostAutoModules
          ++ [hostPath]
          ++ extraModules;
      };

    usuDroid = mkDroidHost {
      hostPath = ./hosts/usu;
    };
  in {
    overlays = {
      packages = packageOverlay;
      default = lib.composeManyExtensions projectOverlays;
    };

    formatter = lib.genAttrs systems (system: nixpkgs.legacyPackages.${system}.alejandra);

    packages = lib.genAttrs systems (
      system:
        (mkFlakePackages system)
        // (lib.optionalAttrs (system == "aarch64-linux") {
          # Deployable rootfs tarball for the AYN Odin 2 Portal nspawn guest.
          # Reuses the upstream packaging plumbing so mountainous owns the
          # *contents* of the guest while nix-on-rocks owns the substrate
          # delivery channel.
          sobo-rootfs = inputs.nix-on-rocks-guest.lib.mkGuestRootfs "aarch64-linux" self.nixosConfigurations.sobo;
        })
    );

    checks.x86_64-linux.gogcli-platforms = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      x86 = self.packages.x86_64-linux.gogcli;
      arm = self.packages.aarch64-linux.gogcli;
    in
      assert lib.assertMsg (x86.meta.platforms == ["aarch64-linux" "x86_64-linux"]) "gogcli metadata must expose every packaged Linux release";
      assert lib.assertMsg (arm.meta.platforms == x86.meta.platforms) "gogcli metadata must stay platform-independent";
      assert lib.assertMsg (x86.releaseArch == "amd64") "gogcli must select the amd64 asset on x86_64-linux";
      assert lib.assertMsg (x86.releaseHash == "sha256-ypi6VuKczTcT/nv4Nf3KAK4bl83LewvF45Pn7bQInIQ=") "gogcli must retain the verified amd64 hash";
      assert lib.assertMsg (arm.releaseArch == "arm64") "gogcli must select the arm64 asset on aarch64-linux";
      assert lib.assertMsg (arm.releaseHash == "sha256-G/6YBUVkFQFIj+2Txm/HZnHHKkYFKF9XRXLaxwDv3TU=") "gogcli must retain the verified arm64 hash";
        pkgs.runCommand "gogcli-platforms" {nativeBuildInputs = [x86];} ''
          gog --version > "$out"
        '';

    checks.x86_64-linux.zao-commitments = let
      commitments = self.nixosConfigurations.zao.config.mountainous.hosts.zao.commitments;
      failed = lib.filterAttrs (_: satisfied: !satisfied) commitments;
      failedNames = lib.concatStringsSep ", " (builtins.attrNames failed);
    in
      assert lib.assertMsg (failed == {}) "Zao has unsatisfied host commitments: ${failedNames}";
        nixpkgs.legacyPackages.x86_64-linux.writeText "zao-commitments.json" (builtins.toJSON commitments);

    checks.x86_64-linux.zao-korri-consumer = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      zao = self.nixosConfigurations.zao.config;
      retirement = zao.systemd.services.zao-retire-korri;
      retirementScript = pkgs.writeText "zao-retire-korri" retirement.script;
      packageNames = map lib.getName zao.environment.systemPackages;
      retiredPackages = ["gamescope" "gamemode" "mangohud" "protontricks"];
      retiredSystemUnits = [
        "greetd"
        "korri-bluetooth-power-on"
        "korri-setup"
        "seatd"
        "zao-korrid-unit-refresh"
      ];
      retiredUserUnits = [
        "korri-compositor"
        "korri-sunshine"
        "korrid"
      ];
      retiredUserTargets = ["korri-session" "sway-session"];
    in
      assert lib.assertMsg zao.services.korriLinuxHost.enable "Zao must consume Korri's isolated Linux host profile";
      assert lib.assertMsg (!(builtins.hasAttr "korri" zao.services)) "Zao must keep the legacy Korri source stack retired";
      assert lib.assertMsg (!zao.programs.sway.enable) "Zao must keep Sway retired";
      assert lib.assertMsg (!zao.programs.steam.enable) "Zao must keep Steam retired";
      assert lib.assertMsg (!zao.programs.gamemode.enable) "Zao must keep GameMode retired";
      assert lib.assertMsg (!zao.xdg.portal.enable) "Zao must keep its desktop portal retired";
      assert lib.assertMsg (!zao.services.greetd.enable) "Zao must keep its local desktop login retired";
      assert lib.assertMsg (!zao.services.seatd.enable) "Zao must keep seatd retired";
      assert lib.assertMsg (!zao.services.pipewire.enable) "Zao must keep the desktop audio session retired";
      assert lib.assertMsg (lib.intersectLists packageNames retiredPackages == []) "Zao must keep broad gaming packages retired";
      assert lib.assertMsg (lib.all (name: !(builtins.hasAttr name zao.systemd.services)) retiredSystemUnits) "Zao must keep legacy Korri system units retired";
      assert lib.assertMsg (lib.all (name: !(builtins.hasAttr name zao.systemd.user.services)) retiredUserUnits) "Zao must keep legacy Korri user services retired";
      assert lib.assertMsg (lib.all (name: !(builtins.hasAttr name zao.systemd.user.targets)) retiredUserTargets) "Zao must keep legacy Korri user targets retired";
      assert lib.assertMsg (builtins.elem "multi-user.target" retirement.wantedBy) "Zao must stop any loaded legacy Korri user services after activation";
      assert lib.assertMsg (retirement.serviceConfig.User == "simonwjackson") "Zao must retire legacy user services through their former owner";
        pkgs.runCommand "zao-korri-consumer" {} ''
          ${pkgs.bash}/bin/bash -n ${retirementScript}
          ${pkgs.gnugrep}/bin/grep -Fq 'stop korri-session.target' ${retirementScript}
          ${pkgs.gnugrep}/bin/grep -Fq 'korrid.service' ${retirementScript}
          ${pkgs.gnugrep}/bin/grep -Fq 'sunshine.service' ${retirementScript}
          ${pkgs.gnugrep}/bin/grep -Fq 'sunshine_backup="$legacy_sunshine.mountainous-retired"' ${retirementScript}
          touch "$out"
        '';

    checks.x86_64-linux.zao-workstation-retired = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      zao = self.nixosConfigurations.zao.config;
    in
      assert lib.assertMsg (!zao.mountainous.presets.workstation.enable) "Zao must not enable the generic workstation preset";
      assert lib.assertMsg zao.networking.networkmanager.enable "Zao must retain explicit NetworkManager ownership";
      assert lib.assertMsg zao.services.avahi.enable "Zao must retain Avahi for printer publication";
      assert lib.assertMsg (zao.services.avahi.nssmdns4 && zao.services.avahi.nssmdns6) "Zao must retain dual-stack mDNS resolution";
      assert lib.assertMsg zao.services.avahi.publish.enable "Zao must retain Avahi publication";
      assert lib.assertMsg zao.services.avahi.publish.userServices "Zao must retain user-service publication for the shared printer";
        pkgs.writeText "zao-workstation-retired" "Zao owns networking and printer discovery without the workstation preset.\n";

    checks.x86_64-linux.zao-runtime-commitments = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      zao = self.nixosConfigurations.zao.config;
      runtimeVerifier = zao.mountainous.hosts.zao.runtimeVerifier;
      script = lib.getExe runtimeVerifier;
      commitmentNames = builtins.attrNames zao.mountainous.hosts.zao.commitments;
      expectedNames = [
        "eval-memory-safety"
        "jellyfin-media-server"
        "media-tiering-sink"
        "shared-office-printer"
        "tailnet-access"
        "towada-storage"
      ];
      namesFile = pkgs.writeText "zao-runtime-commitment-names" (lib.concatLines commitmentNames);
    in
      assert lib.assertMsg (commitmentNames == expectedNames) "Zao must retain exactly its six non-Korri commitments";
      assert lib.assertMsg (builtins.elem runtimeVerifier zao.environment.systemPackages) "Zao must install its runtime commitment verifier";
        pkgs.runCommand "zao-runtime-commitments" {} ''
          ${pkgs.bash}/bin/bash -n ${script}

          while IFS= read -r name; do
            ${pkgs.gnugrep}/bin/grep -Fq "$name" ${script}
          done < ${namesFile}

          ${pkgs.gnugrep}/bin/grep -Fq 'fuse.mergerfs' ${script}
          ${pkgs.gnugrep}/bin/grep -Fq 'Office_Printer' ${script}
          ${pkgs.gnugrep}/bin/grep -Fq 'zramctl' ${script}
          ${pkgs.gnugrep}/bin/grep -Fq 'expect_mount_device' ${script}
          ${pkgs.gnugrep}/bin/grep -Fq '/dev/disk/by-id/usb-TerraMas_TDAS_7SGKDA3C-0:0-part1' ${script}
          ${pkgs.gnugrep}/bin/grep -Fq '/dev/disk/by-id/usb-TerraMas_TDAS_VGH13XMG-0:0-part1' ${script}
          ${pkgs.gnugrep}/bin/grep -Fq 'getfattr --name=user.mergerfs.branches' ${script}
          ${pkgs.gnugrep}/bin/grep -Fq 'mounted_source="$(findmnt' ${script}
          ${pkgs.gnugrep}/bin/grep -Fq 'head --lines=1 || true)' ${script}
          ${pkgs.gnugrep}/bin/grep -Fq ' disabled ' ${script}

          if ${pkgs.gnugrep}/bin/grep -Eqi 'korri|sunshine|sway|steam|pipewire|wireplumber|seatd|uinput' ${script}; then
            echo "Zao runtime commitments must not retain retired Korri capabilities" >&2
            exit 1
          fi
          if ${pkgs.gnugrep}/bin/grep -Eq '(^|[^[:alnum:]_-])(ping|showmount|yari)([^[:alnum:]_-]|$)' ${script}; then
            echo "Zao runtime commitments must not depend on Yari or another peer" >&2
            exit 1
          fi

          touch "$out"
        '';

    checks.x86_64-linux.zao-media-normalization = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      zao = self.nixosConfigurations.zao.config;
      normalizationUnit = "mountainous-media-normalize-permissions.service";
      service = zao.systemd.services.mountainous-media-normalize-permissions;
      timer = zao.systemd.timers.mountainous-media-normalize-permissions;
      jellyfin = zao.systemd.services.jellyfin;
      script = service.serviceConfig.ExecStart;
      nestedMountConfig =
        (lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./features/media/default.nix
            ({lib, ...}: {
              options.mountainous.features =
                lib.genAttrs [
                  "media-tiering"
                  "jellyfin"
                  "radarr"
                  "sonarr"
                  "nzbget"
                  "transmission"
                ] (_: {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                  };
                });

              config = {
                mountainous.features.media = {
                  enable = true;
                  root = "/srv/library";
                  mediaRoot = "/srv/library/media-volume/media";
                };
                fileSystems."/srv/library/media-volume" = {
                  device = "none";
                  fsType = "tmpfs";
                };
                system.stateVersion = "26.05";
              };
            })
          ];
        }).config;
      nestedMountScript = nestedMountConfig.systemd.services.mountainous-media-normalize-permissions.serviceConfig.ExecStart;
    in
      assert lib.assertMsg (!(builtins.elem "multi-user.target" service.wantedBy)) "Zao media normalization must not block multi-user.target";
      assert lib.assertMsg (builtins.elem "timers.target" timer.wantedBy) "Zao media normalization must retain its timer";
      assert lib.assertMsg (timer.timerConfig.OnActiveSec == "15min") "Zao media normalization must wait 15 minutes after timer activation";
      assert lib.assertMsg (timer.timerConfig.OnUnitActiveSec == "6h") "Zao media normalization must retain its six-hour schedule";
      assert lib.assertMsg (!(builtins.elem normalizationUnit jellyfin.after)) "Jellyfin must not wait for Zao media normalization";
      assert lib.assertMsg (!(builtins.elem normalizationUnit jellyfin.wants)) "Jellyfin must not start Zao media normalization";
        pkgs.runCommand "zao-media-normalization" {} ''
          root_count=$(${pkgs.gnugrep}/bin/grep -Ec '^[[:space:]]*normalize_root[[:space:]]+' ${script})
          if [ "$root_count" -ne 1 ]; then
            echo "expected one Zao normalization root, found $root_count" >&2
            exit 1
          fi
          ${pkgs.gnugrep}/bin/grep -Eq '^[[:space:]]*normalize_root[[:space:]]+/srv/lakes/towada$' ${script}

          nested_root_count=$(${pkgs.gnugrep}/bin/grep -Ec '^[[:space:]]*normalize_root[[:space:]]+' ${nestedMountScript})
          if [ "$nested_root_count" -ne 2 ]; then
            echo "expected two roots across the nested filesystem boundary, found $nested_root_count" >&2
            exit 1
          fi
          ${pkgs.gnugrep}/bin/grep -Eq '^[[:space:]]*normalize_root[[:space:]]+/srv/library$' ${nestedMountScript}
          ${pkgs.gnugrep}/bin/grep -Eq '^[[:space:]]*normalize_root[[:space:]]+/srv/library/media-volume/media$' ${nestedMountScript}

          touch "$out"
        '';

    checks.x86_64-linux.zao-jellyfin-bootstrap = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      script = self.nixosConfigurations.zao.config.systemd.services.jellyfin-seed-bootstrap.script;
      scriptFile = pkgs.writeText "zao-jellyfin-bootstrap.sh" script;
    in
      pkgs.runCommand "zao-jellyfin-bootstrap" {} ''
        ${pkgs.gnused}/bin/sed -n "/<<'PY'$/,/^PY$/p" ${scriptFile} \
          | ${pkgs.gnused}/bin/sed '1d;$d' > bootstrap.py
        test -s bootstrap.py
        ${pkgs.python3}/bin/python -m py_compile bootstrap.py
        ${pkgs.gnugrep}/bin/grep -Fq 'known_initialized=known_initialized' bootstrap.py
        ${pkgs.gnugrep}/bin/grep -Fq 'known_initialized=True' bootstrap.py
        touch "$out"
      '';

    checks.x86_64-linux.zao-esp-mirror = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      script = self.nixosConfigurations.zao.config.system.build.installBootLoader;
    in
      pkgs.runCommand "zao-esp-mirror" {} ''
        ${pkgs.gnugrep}/bin/grep -Fq '${pkgs.coreutils}/bin/mkdir -p /boot/efi-backup' ${script}
        if ${pkgs.gnugrep}/bin/grep -Eq '^mkdir[[:space:]]' ${script}; then
          echo "Zao boot installer must not rely on PATH for mkdir" >&2
          exit 1
        fi
        ${pkgs.gnugrep}/bin/grep -Fq '/dev/disk/by-partlabel/disk-nvme1-ESP /boot/efi-backup' ${script}
        ${pkgs.gnugrep}/bin/grep -Fq -- "--exclude='/efi-backup' /boot/ /boot/efi-backup/" ${script}
        ${pkgs.gnugrep}/bin/grep -Fq '/bin/umount /boot/efi-backup' ${script}
        touch "$out"
      '';

    checks.x86_64-linux.zao-peer-media = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      zao = self.nixosConfigurations.zao.config;
      yari = self.nixosConfigurations.yari.config;
      serviceName = "media-tiering-peer-mount";
      peerRoot = zao.mountainous.features.media-tiering.peerMountRoot;
      yariPeerRoot = yari.mountainous.features.media-tiering.peerMountRoot;
      serviceExists = builtins.hasAttr serviceName zao.systemd.services;
      service = zao.systemd.services.${serviceName};
      timer = zao.systemd.timers.${serviceName};
      scriptPath = builtins.head (lib.splitString " " service.serviceConfig.ExecStart);
      rangeMoviesDir = zao.mountainous.features.media.rangeMoviesDir;
      rangeTvDir = zao.mountainous.features.media.rangeTvDir;
      localBackingRoot = zao.mountainous.features.media-tiering.localBackingRoot;
      zaoTmpfiles = zao.systemd.tmpfiles.rules;
      yariMountOptions = yari.fileSystems.${yariPeerRoot}.options;
    in
      assert lib.assertMsg serviceExists "Zao must use a best-effort peer media mount service";
      assert lib.assertMsg (!(builtins.hasAttr peerRoot zao.fileSystems)) "Zao peer media must not create a failing systemd mount unit";
      assert lib.assertMsg (service.wantedBy == []) "Zao peer media mount must stay outside the activation transaction";
      assert lib.assertMsg (builtins.elem "timers.target" timer.wantedBy) "Zao peer media mount must retain its retry timer";
      assert lib.assertMsg (timer.timerConfig.OnActiveSec == "30s") "Zao peer media retry must start after activation";
      assert lib.assertMsg (timer.timerConfig.OnUnitInactiveSec == "5min") "Zao peer media retry must continue every five minutes";
      assert lib.assertMsg (zao.fileSystems.${rangeMoviesDir}.device == "${localBackingRoot}/movies") "Zao movies must start with its local branch only";
      assert lib.assertMsg (zao.fileSystems.${rangeTvDir}.device == "${localBackingRoot}/tv") "Zao TV must start with its local branch only";
      assert lib.assertMsg (lib.all (rule: !(lib.hasInfix peerRoot rule)) zaoTmpfiles) "Zao tmpfiles must not touch the peer mount path";
      assert lib.assertMsg (builtins.hasAttr yariPeerRoot yari.fileSystems) "Yari must retain its on-demand Zao mount";
      assert lib.assertMsg (builtins.elem "x-systemd.automount" yariMountOptions) "Yari must retain peer media automounting";
        pkgs.runCommand "zao-peer-media" {} ''
          ${pkgs.gnugrep}/bin/grep -Fq 'timeo=10,retrans=1' ${scriptPath}
          ${pkgs.gnugrep}/bin/grep -Fq 'retry=0' ${scriptPath}
          ${pkgs.gnugrep}/bin/grep -Fq 'timeout --signal=TERM --kill-after=2s 10s' ${scriptPath}
          ${pkgs.gnugrep}/bin/grep -Fq 'peer_is_healthy' ${scriptPath}
          ${pkgs.gnugrep}/bin/grep -Fq 'user.mergerfs.branches' ${scriptPath}
          ${pkgs.gnugrep}/bin/grep -Fq 'mount_status=$?' ${scriptPath}
          ${pkgs.gnugrep}/bin/grep -Fq 'exit 0' ${scriptPath}
          touch "$out"
        '';

    nixosConfigurations = {
      fuji = mkHost {
        system = "aarch64-linux";
        hostPath = ./hosts/fuji;
      };
      yari = mkHost {
        system = "aarch64-linux";
        hostPath = ./hosts/yari;
      };
      rakku = mkHost {
        system = "x86_64-linux";
        hostPath = ./hosts/rakku;
        extraModules = [impermanence.nixosModules.default];
        specialArgs = {
          inherit gomod2nix;
        };
      };
      kita = mkHost {
        system = "x86_64-linux";
        hostPath = ./hosts/kita;
      };
      yuki = mkHost {
        system = "x86_64-linux";
        hostPath = ./hosts/yuki;
        specialArgs = {inherit nixos-hardware;};
      };
      aso = mkHost {
        system = "x86_64-linux";
        hostPath = ./hosts/aso;
        extraModules = [nixos-wsl.nixosModules.default];
      };
      aka = mkHost {
        system = "x86_64-linux";
        hostPath = ./hosts/aka;
        extraModules = [inputs.korri.nixosModules.korri-source-machine];
      };
      # AYN Odin 2 Portal: NixOS guest inside a systemd-nspawn container on
      # patched ROCKNIX. Device hostname is forced to "sobo" by the upstream
      # device profile. Module composition order: SM8550 options schema, then
      # the main-space profile, then the device profile (which overrides only
      # the measured per-device differences).
      sobo = mkHost {
        system = "aarch64-linux";
        hostPath = ./hosts/sobo;
        specialArgs = {
          korriHasKiosk = true;
        };
        extraModules = [
          inputs.nix-on-rocks-guest.nixosModules.sm8550
          inputs.nix-on-rocks-guest.nixosModules.main-space
          inputs.nix-on-rocks-guest.nixosModules.odin2portal
          inputs.korri.nixosModules.korri
          inputs.korri.nixosModules.korri-sessiond
          "${inputs.korri}/product/systems/nixos/images/kiosk.nix"
        ];
      };
      zao = mkHost {
        system = "x86_64-linux";
        hostPath = ./hosts/zao;
        extraModules = [inputs.korri-input-host.nixosModules.korri-linux-host];
      };
      ibuki = mkHost {
        system = "x86_64-linux";
        hostPath = ./hosts/ibuki;
      };
    };

    nixOnDroidConfigurations = {
      usu = usuDroid;
      default = usuDroid;
    };

    devShells = lib.genAttrs systems (
      system: let
        pkgs = mkPkgs system;
      in {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [
            gitleaks
          ];
        };
      }
    );
  };
}
