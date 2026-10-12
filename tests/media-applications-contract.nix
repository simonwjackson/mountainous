# Admitted production placement and every controlled processing stage preserve releases and startup gates.
let
  flake = builtins.getFlake (toString ../.);
  declared = flake.nixosConfigurations.unzen.config;
  target =
    (flake.nixosConfigurations.unzen.extendModules {
      modules = [
        (
          { lib, ... }:
          {
            mountainous.features.media-applications.processing = lib.mkForce "held";
          }
        )
      ];
    }).config;
  split =
    (flake.nixosConfigurations.unzen.extendModules {
      modules = [
        {
          mountainous.features.media-applications.placement.sonarr = "other-host";
        }
      ];
    }).config;
  remoteDownloader =
    (flake.nixosConfigurations.unzen.extendModules {
      modules = [
        {
          mountainous.features.media-applications.placement.nzbget = "other-downloader-host";
        }
      ];
    }).config;
  remoteArr =
    (flake.nixosConfigurations.unzen.extendModules {
      modules = [
        {
          mountainous.features.media-applications.placement = {
            sonarr = "other-arr-host";
            radarr = "other-arr-host";
          };
        }
      ];
    }).config;
  importsOnly =
    (flake.nixosConfigurations.unzen.extendModules {
      modules = [
        {
          mountainous.features.media-applications.processing = "imports-only";
        }
      ];
    }).config;
  arrEnabled =
    (flake.nixosConfigurations.unzen.extendModules {
      modules = [ { mountainous.features.media-applications.processing = "arr-enabled"; } ];
    }).config;
  normal =
    (flake.nixosConfigurations.unzen.extendModules {
      modules = [ { mountainous.features.media-applications.processing = "enabled"; } ];
    }).config;
  usenetConfig =
    usenet: held:
    (flake.nixosConfigurations.unzen.extendModules {
      modules = [
        ({ lib, ... }: {
          mountainous.features.media-applications = {
            usenet = lib.mkForce usenet;
            nzbfast.held = lib.mkForce held;
          };
        })
      ];
    }).config;
  nzbgetOnly = usenetConfig "nzbget" true;
  nzbfastOnly = usenetConfig "nzbfast" true;
  releasedFast = usenetConfig "both" false;
  globallyHeldFast =
    (flake.nixosConfigurations.unzen.extendModules {
      modules = [
        ({ lib, ... }: {
          mountainous.features.media-applications = {
            processing = lib.mkForce "held";
            nzbfast.held = lib.mkForce false;
          };
        })
      ];
    }).config;
  fast = declared.systemd.services.nzbfast;
  apps = [
    "sonarr"
    "radarr"
    "prowlarr"
    "nzbget"
    "transmission"
  ];
  versions = {
    sonarr = "4.0.16.2944";
    radarr = "6.0.4.10291";
    prowlarr = "2.3.0.5236";
    nzbget = "26.0";
    transmission = "4.1.1";
  };
in
assert nzbgetOnly.services.nzbget.enable && !nzbgetOnly.services.nzbfast.enable;
assert !(nzbgetOnly.systemd.services ? nzbfast);
assert declared.services.nzbget.enable && declared.services.nzbfast.enable;
assert nzbfastOnly.services.nzbfast.enable && !nzbfastOnly.services.nzbget.enable;
assert !(nzbfastOnly.systemd.services ? nzbget);
assert !builtins.elem "nzbget.service" nzbfastOnly.systemd.services.media-vpn.wants;
assert !(declared.systemd.services ? tsnet-proxy-nzbfast);
assert declared.services.nzbfast.package.version == "1.7.1";
assert declared.users.users.nzbfast.uid == 391;
assert declared.users.users.nzbfast.group == "media";
assert
  builtins.length (builtins.filter (user: user.uid == 391) (builtins.attrValues declared.users.users))
  == 1;
assert fast.unitConfig.ConditionPathExists == "/var/lib/media-migration/ready/nzbfast";
assert fast.unitConfig.ConditionFileNotEmpty == [ "/var/lib/nzbfast/config.json" ];
assert fast.serviceConfig.NetworkNamespacePath == "/run/netns/vpn";
assert builtins.elem "-/run/nscd" fast.serviceConfig.InaccessiblePaths;
assert builtins.match ".*media-vpn-nss-modules" fast.environment.LD_LIBRARY_PATH != null;
assert builtins.elem "media-vpn.service" fast.bindsTo;
assert builtins.elem "media-vpn.service" fast.requires;
assert builtins.elem "media-vpn.service" fast.after;
assert builtins.elem "nzbfast.service" declared.systemd.services.media-vpn.wants;
assert builtins.elem "/etc/netns/vpn/resolv.conf:/etc/resolv.conf"
  fast.serviceConfig.BindReadOnlyPaths;
assert fast.serviceConfig.UMask == "0002";
assert fast.environment.NZBFAST_NO_ENRICH == "1";
assert declared.services.nzbfast.port == 6790;
assert declared.services.nzbfast.listenAddress == "0.0.0.0";
assert !declared.services.nzbfast.openFirewall;
assert
  builtins.match ".*media-state-ready.py nzbfast.*media-nzbfast-settings.py /var/lib/nzbfast held.*jq.*" fast.preStart
  != null;
assert
  builtins.match ".*media-nzbfast-settings.py /var/lib/nzbfast enabled.*" releasedFast.systemd.services.nzbfast.preStart
  != null;
assert
  builtins.match ".*media-nzbfast-settings.py /var/lib/nzbfast held.*" globallyHeldFast.systemd.services.nzbfast.preStart
  != null;
assert
  builtins.match ".*password.*" (
    builtins.toJSON {
      inherit (fast)
        preStart
        environment
        serviceConfig
        unitConfig
        ;
      service = declared.services.nzbfast;
    }
  ) == null;
assert builtins.all (name: target.services.${name}.package.version == versions.${name}) apps;
assert builtins.all (
  name:
  target.systemd.services.${name}.unitConfig.ConditionPathExists
  == "/var/lib/media-migration/ready/${name}"
) apps;
assert builtins.all (
  name: builtins.length target.systemd.services.${name}.unitConfig.ConditionFileNotEmpty > 0
) apps;
assert builtins.length target.systemd.services.transmission.serviceConfig.ExecStartPre == 1;
assert
  builtins.match ".*media-state-ready.py transmission" (
    builtins.head target.systemd.services.transmission.serviceConfig.ExecStartPre
  ) != null;
assert target.services.sonarr.dataDir == "/var/lib/sonarr/.config/NzbDrone";
assert target.services.radarr.dataDir == "/var/lib/radarr/.config/Radarr";
assert target.services.prowlarr.dataDir == "/var/lib/prowlarr";
assert target.services.transmission.home == "/var/lib/transmission";
assert target.users.groups.media.gid == 390;
assert target.fileSystems."/srv/media-library-view/tv".fsType == "fuse.bindfs";
assert builtins.elem "force-user=274" target.fileSystems."/srv/media-library-view/tv".options;
assert builtins.elem "force-user=275" target.fileSystems."/srv/media-library-view/movies".options;
assert builtins.elem "create-for-user=0" target.fileSystems."/srv/media-library-view/tv".options;
assert builtins.elem "map=@993/@390" target.fileSystems."/srv/media-library-view/tv".options;
assert builtins.elem "default_permissions" target.fileSystems."/srv/media-library-view/tv".options;
assert builtins.elem "chown-deny" target.fileSystems."/srv/media-library-view/tv".options;
assert builtins.elem "chgrp-deny" target.fileSystems."/srv/media-library-view/tv".options;
assert
  target.fileSystems."/srv/range/media/tv".device == "/srv/basin/media/tv:/srv/media-library-view/tv";
assert !split.services.sonarr.enable;
assert split.services.radarr.enable;
assert builtins.all (name: target.services.${name}.enable) apps;
assert target.mountainous.features.media-applications.processing == "held";
assert declared.mountainous.features.media-applications.processing == "enabled";
assert importsOnly.mountainous.features.media-applications.processing == "imports-only";
assert
  builtins.match "[+].*--imports-only.*sonarr.json.*" (
    builtins.head importsOnly.systemd.services.sonarr.serviceConfig.ExecStartPre
  ) != null;
assert
  builtins.match "[+].*--imports-only.*radarr.json.*" (
    builtins.head importsOnly.systemd.services.radarr.serviceConfig.ExecStartPre
  ) != null;
assert builtins.match ".*--hold.*" importsOnly.systemd.services.prowlarr.preStart != null;
assert
  builtins.match ".*nzbget held .*" importsOnly.systemd.services.nzbget.serviceConfig.ExecStart
  != null;
assert builtins.elem "--paused" importsOnly.services.transmission.extraFlags;
assert importsOnly.systemd.timers.media-library-mover-nightly.wantedBy == [ ];
assert importsOnly.systemd.timers.media-library-mover-low-space.wantedBy == [ ];
assert builtins.all
  (name: builtins.match ".*--hold.*" arrEnabled.systemd.services.${name}.preStart == null)
  [
    "sonarr"
    "radarr"
    "prowlarr"
  ];
assert
  builtins.match ".*nzbget held .*" arrEnabled.systemd.services.nzbget.serviceConfig.ExecStart
  != null;
assert builtins.elem "--paused" arrEnabled.services.transmission.extraFlags;
assert arrEnabled.systemd.timers.media-library-mover-nightly.wantedBy == [ ];
assert arrEnabled.systemd.timers.media-library-mover-low-space.wantedBy == [ ];
assert
  builtins.match ".*nzbget enabled .*" normal.systemd.services.nzbget.serviceConfig.ExecStart != null;
assert builtins.all
  (
    name:
    builtins.match "[+].*--enabled.*${name}.json.*" (
      builtins.head arrEnabled.systemd.services.${name}.serviceConfig.ExecStartPre
    ) != null
  )
  [
    "sonarr"
    "radarr"
    "prowlarr"
  ];
assert builtins.all
  (
    name:
    builtins.match "[+].*--enabled.*${name}.json.*" (
      builtins.head normal.systemd.services.${name}.serviceConfig.ExecStartPre
    ) != null
  )
  [
    "sonarr"
    "radarr"
    "prowlarr"
  ];
assert !builtins.elem "--paused" normal.services.transmission.extraFlags;
assert normal.systemd.timers.media-library-mover-nightly.wantedBy == [ "timers.target" ];
assert builtins.all (app: builtins.elem "${app}.service" target.systemd.services.media-vpn.wants) [
  "prowlarr"
  "nzbget"
  "transmission"
];
assert !builtins.elem "nzbget.service" remoteDownloader.systemd.services.media-vpn.wants;
assert
  !builtins.elem "srv-basin-downloads-usenet-completed.mount" target.systemd.services.media-storage-ready.bindsTo;
assert
  !builtins.elem "srv-basin-downloads-torrents-completed.mount" target.systemd.services.media-storage-ready.bindsTo;
assert builtins.elem "/srv/basin/downloads/usenet/completed"
  target.systemd.services.media-storage-ready.unitConfig.RequiresMountsFor;
assert builtins.elem "srv-basin-downloads-usenet-completed.mount"
  remoteDownloader.systemd.services.media-storage-ready.bindsTo;
assert builtins.elem "net-mountainous-zao-media.mount"
  target.systemd.services.media-storage-ready.bindsTo;
assert builtins.all (
  name:
  target.systemd.services."tsnet-proxy-${name}".unitConfig.ConditionPathExists
  == "/var/lib/media-migration/ready/${name}"
) apps;
assert builtins.elem "/var/lib/media-migration/ready/vpn"
  target.systemd.services.media-vpn.unitConfig.ConditionPathExists;
assert builtins.all
  (
    name:
    builtins.elem "-/run/nscd" declared.systemd.services.${name}.serviceConfig.InaccessiblePaths
    && declared.systemd.services.${name}.serviceConfig.NetworkNamespacePath == "/run/netns/vpn"
    &&
      builtins.match ".*media-vpn-nss-modules"
        declared.systemd.services.${name}.environment.LD_LIBRARY_PATH != null
  )
  [
    "prowlarr"
    "nzbget"
    "transmission"
  ];
assert builtins.elem "--paused" target.services.transmission.extraFlags;
assert builtins.elem "--no-watch-dir" target.services.transmission.extraFlags;
assert target.mountainous.features.media-runtime.libraryMover.enable;
assert remoteArr.fileSystems."/net/mountainous/zao/media".fsType == "nfs";
assert remoteArr.fileSystems."/srv/media-library-view/tv".fsType == "fuse.bindfs";
assert builtins.elem "/var/lib/media-migration/ready/library-mover"
  target.systemd.services."media-library-mover@".unitConfig.ConditionPathExists;
assert target.systemd.timers.media-library-mover-nightly.wantedBy == [ ];
assert target.systemd.timers.media-library-mover-low-space.wantedBy == [ ];
assert
  builtins.match ".*Category1.Name=Movies.*" target.systemd.services.nzbget.serviceConfig.ExecStart
  != null;
assert
  builtins.match ".*Category2.Name=Series.*" target.systemd.services.nzbget.serviceConfig.ExecStart
  != null;
{
  status = "pass";
  targetDerivation = declared.system.build.toplevel.drvPath;
  preservesApplicationReleases = true;
  requiresExistingState = true;
  transmissionSettingsAreNotRegenerated = true;
  independentPlacementEvaluates = true;
  localStagingUsesFilesystemDependencies = true;
  remoteStagingRetainsMountLossFence = true;
  namespaceRecoveryUsesOnlyLocalConsumers = true;
  productionStartupGated = true;
  productionProcessingEnabledAfterAcceptance = true;
  clientMappedLibraryEvaluates = true;
  storedLibraryOwnershipChangesDenied = true;
  libraryHandoffIndependentOfArrPlacement = true;
  libraryHandoffGatedWhileProcessingHeld = true;
  retainedNzbgetCategoriesDeclared = true;
  importsOnlyStartupRequiresProtectedOriginalReceipts = true;
  importsOnlyKeepsDownloadersIndexersAndMoverTimersHeld = true;
  arrEnabledKeepsDownloaderLaunchesAndMoverTimersHeld = true;
  normalProcessingStartupAndTimersAdmitted = true;
  vpnConsumersCannotResolveThroughHostNscd = true;
}
