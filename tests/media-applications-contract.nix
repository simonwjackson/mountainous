# The declared Unzen placement preserves releases and requires held startup gates.
let
  flake = builtins.getFlake (toString ../.);
  target = flake.nixosConfigurations.unzen.config;
  split =
    (flake.nixosConfigurations.unzen.extendModules {
      modules = [
        {
          mountainous.features.media-applications.placement.sonarr = "other-host";
        }
      ];
    }).config;
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
assert builtins.all (
  name:
  target.systemd.services."tsnet-proxy-${name}".unitConfig.ConditionPathExists
  == "/var/lib/media-migration/ready/${name}"
) apps;
assert builtins.elem "/var/lib/media-migration/ready/vpn"
  target.systemd.services.media-vpn.unitConfig.ConditionPathExists;
assert builtins.elem "--paused" target.services.transmission.extraFlags;
assert builtins.elem "--no-watch-dir" target.services.transmission.extraFlags;
{
  status = "pass";
  targetDerivation = target.system.build.toplevel.drvPath;
  preservesApplicationReleases = true;
  requiresExistingState = true;
  transmissionSettingsAreNotRegenerated = true;
  independentPlacementEvaluates = true;
  productionStartupGated = true;
  productionProcessingHeld = true;
  clientMappedLibraryEvaluates = true;
  storedLibraryOwnershipChangesDenied = true;
}
