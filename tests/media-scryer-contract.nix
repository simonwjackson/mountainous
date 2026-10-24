# nix eval --impure --expr 'import ./tests/media-scryer-contract.nix {}'
{
  flake ? builtins.getFlake (toString ../.),
}:
let
  # This contract covers the NFS placement modes, so it evaluates Unzen with
  # the library on Zao. The local Towada layout has its own host check.
  host = flake.nixosConfigurations.unzen.extendModules {
    modules = [
      (
        { lib, ... }:
        {
          mountainous.features.towada.enable = lib.mkForce false;
        }
      )
    ];
  };
  configFor =
    library: tailnet:
    (host.extendModules {
      modules = [
        (
          { lib, ... }:
          {
            mountainous.features.media-applications = {
              library = lib.mkForce library;
              scryerTailnet = lib.mkForce tailnet;
            };
          }
        )
      ];
    }).config;
  arr = configFor "arr" false;
  both = configFor "both" false;
  scryer = configFor "scryer" false;
  bothTailnet = configFor "both" true;
  scryerTailnet = configFor "scryer" true;
  arrTailnet = configFor "arr" true;
  units = config: config.systemd.units;
  lib = flake.inputs.nixpkgs.lib;
  libraryPaths = [
    "/srv/range/media/tv"
    "/srv/range/media/movies"
    "/srv/basin/media"
    "/srv/media-library-view"
    "/net/mountainous/zao/media"
  ];
  bindfs =
    config:
    map (path: config.fileSystems.${path}) [
      "/srv/media-library-view/tv"
      "/srv/media-library-view/movies"
    ];
  scryerContract =
    config:
    let
      service = config.systemd.services.scryer;
    in
    config.users.users.scryer.uid == 392
    && config.users.users.scryer.group == "media"
    && service.serviceConfig.UMask == "0002"
    && config.services.scryer.port == 8080
    && config.services.scryer.listenAddress == "127.0.0.1"
    && service.environment.SCRYER_AUTH_ENABLED == "true"
    && config.services.scryer.waitForReady
    && service.unitConfig.ConditionPathExists == "/var/lib/media-migration/ready/scryer"
    &&
      service.unitConfig.ConditionFileNotEmpty
      == [ "/var/lib/media-migration/credentials/scryer-admin-password" ]
    && builtins.elem "admin-password:/var/lib/media-migration/credentials/scryer-admin-password" service.serviceConfig.LoadCredential
    && !lib.hasInfix "SCRYER_ADMIN_PASSWORD=" (units config)."scryer.service".text
    && !(service.serviceConfig ? NetworkNamespacePath)
    && builtins.elem "media-storage-ready.service" service.requires
    && builtins.elem "media-storage-ready.service" service.after
    && builtins.elem "media-storage-ready.service" service.bindsTo
    && (service.serviceConfig.ExecCondition or [ ]) != [ ]
    && builtins.all (mount: builtins.elem mount service.bindsTo) [
      "net-mountainous-zao-media.mount"
      "srv-media\\x2dlibrary\\x2dview-tv.mount"
      "srv-media\\x2dlibrary\\x2dview-movies.mount"
      "srv-range-media-tv.mount"
      "srv-range-media-movies.mount"
    ];
  comparisons = {
    productionScryerProxy =
      host.config.mountainous.features.media-applications.scryerTailnet
      && lib.hasInfix "-hostname scryer" (units host.config)."tsnet-proxy-scryer.service".text
      && host.config.systemd.services.tsnet-proxy-scryer.requires == [ "scryer.service" ];
    arrHasOnlyArr =
      (units arr) ? "sonarr.service"
      && (units arr) ? "radarr.service"
      && !((units arr) ? "scryer.service");
    bothHasAll =
      (units both) ? "sonarr.service"
      && (units both) ? "radarr.service"
      && (units both) ? "scryer.service";
    scryerHasOnlyScryer =
      !((units scryer) ? "sonarr.service")
      && !((units scryer) ? "radarr.service")
      && (units scryer) ? "scryer.service";
    arrUnitsUnchangedInBoth =
      builtins.all (name: (units arr).${name}.text == (units both).${name}.text)
        [
          "sonarr.service"
          "radarr.service"
          "tsnet-proxy-sonarr.service"
          "tsnet-proxy-radarr.service"
        ];
    bothLibraryReadOnly =
      both.services.scryer.readOnlyPaths == libraryPaths
      && both.services.scryer.writablePaths == [ ]
      && both.systemd.services.scryer.serviceConfig.ReadWritePaths == [ "/var/lib/scryer" ];
    scryerImportWrites =
      builtins.all (path: builtins.elem path scryer.systemd.services.scryer.serviceConfig.ReadWritePaths)
        [
          "/srv/range/media/tv"
          "/srv/range/media/movies"
          "/srv/basin/media/tv"
          "/srv/basin/media/movies"
          "/srv/basin/downloads/usenet/nzbfast"
          "/srv/basin/downloads/torrents/completed"
        ];
    leastDownloaderAccess =
      !builtins.elem "/srv/basin/downloads" scryer.services.scryer.writablePaths
      && !builtins.elem "/srv/basin/downloads/torrents/incomplete" scryer.services.scryer.writablePaths;
    privateTrialNamespace = both.systemd.services.scryer.serviceConfig.MountFlags == "private";
    exportTreeAlwaysHidden =
      builtins.all
        (
          config:
          builtins.elem "/srv/media-access" config.systemd.services.scryer.serviceConfig.InaccessiblePaths
        )
        [
          both
          scryer
        ];
    # Mount loss must stop the consumer, but rebuilding a view must not resume
    # processing. The real Scryer VM checks the subsequent explicit start.
    mountLossStopsWithoutAutomaticResume =
      builtins.all
        (
          config:
          builtins.all (
            mount:
            builtins.elem mount config.systemd.services.scryer.requires
            && builtins.elem mount config.systemd.services.scryer.after
            && !(builtins.elem mount config.systemd.services.scryer.partOf)
          ) config.systemd.services.scryer.bindsTo
        )
        [
          both
          scryer
        ];
    serviceIdentityAndGates = scryerContract both && scryerContract scryer;
    # The signed upstream release binary (nix-extras pkgs/scryer/release.nix):
    # only it can enroll with SMG; a source build gets 401 and never hydrates.
    signedScryerReleaseIdentity =
      scryer.services.scryer.package.version == "0.21.15"
      &&
        scryer.services.scryer.package.outPath
        == "/nix/store/k9d6hb7dn2lys8bpjq6q7a20p8iv0lav-scryer-0.21.15";
    bindfsUnchanged = bindfs arr == bindfs both && bindfs arr == bindfs scryer;
    libraryMountsRetained =
      arr.fileSystems."/srv/range/media/tv" == scryer.fileSystems."/srv/range/media/tv"
      && arr.fileSystems."/net/mountainous/zao/media" == scryer.fileSystems."/net/mountainous/zao/media";
    noLibraryProxyByDefault =
      !((units both) ? "tsnet-proxy-scryer.service")
      && !((units scryer) ? "tsnet-proxy-scryer.service")
      && !((units arrTailnet) ? "tsnet-proxy-scryer.service");
    explicitLibraryProxy =
      lib.hasInfix "-hostname scryer" (units bothTailnet)."tsnet-proxy-scryer.service".text
      &&
        lib.hasInfix "-backend http://127.0.0.1:8080"
          (units scryerTailnet)."tsnet-proxy-scryer.service".text;
    scryerHasNoArrProxies =
      !((units scryerTailnet) ? "tsnet-proxy-sonarr.service")
      && !((units scryerTailnet) ? "tsnet-proxy-radarr.service");
    modeAwareAudit =
      (builtins.fromJSON scryer.environment.etc."media-vpn-leak-audit.json".text).hostUnits
      == [ "scryer.service" ]
      &&
        (builtins.fromJSON both.environment.etc."media-vpn-leak-audit.json".text).hostUnits == [
          "sonarr.service"
          "radarr.service"
          "scryer.service"
        ];
  };
in
assert builtins.all (value: value) (builtins.attrValues comparisons);
{
  status = "pass";
  inherit comparisons;
}
