{
  config,
  lib,
  ...
}: let
  inherit (lib)
    mkIf
    mapAttrs
    filter
    attrNames
    optionalAttrs
    mapAttrsToList
    all
    foldl'
    ;

  cfg = config.mountainous.features.syncthing;
  hostname = config.networking.hostName;

  # ── Device discovery from plain files ────────────────────────────────
  # NixOS hosts expose Syncthing metadata via `hosts/<name>/syncthing.nix`.
  # External devices (phones, etc.) still use `devices/<name>/syncthing-device-id`.

  hostsRoot = ../../hosts;
  devicesRoot = ../../devices;

  discoverHostManifests =
    root:
    let
      entries = if builtins.pathExists root then builtins.readDir root else { };
      dirs = attrNames (lib.filterAttrs (_: type: type == "directory") entries);
      hasManifest = name: builtins.pathExists (root + "/${name}/syncthing.nix");
      withManifests = filter hasManifest dirs;
    in
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = import (root + "/${name}/syncthing.nix");
      }) withManifests
    );

  discoverExternalDevices =
    root:
    let
      entries = if builtins.pathExists root then builtins.readDir root else { };
      dirs = attrNames (lib.filterAttrs (_: type: type == "directory") entries);
      hasId = name: builtins.pathExists (root + "/${name}/syncthing-device-id");
      withIds = filter hasId dirs;
    in
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = lib.removeSuffix "\n" (builtins.readFile (root + "/${name}/syncthing-device-id"));
      }) withIds
    );

  hostManifests = discoverHostManifests hostsRoot;

  # Device IDs come from host manifests plus any external non-host devices.
  allDeviceIds = (mapAttrs (_: manifest: manifest.deviceId) hostManifests) // (discoverExternalDevices devicesRoot);
  allDeviceNames = attrNames allDeviceIds;

  # Share membership is derived only from enabled shares declared by hosts.
  hostEnabledShares = mapAttrs (
    _: manifest:
    attrNames (lib.filterAttrs (_: shareCfg: shareCfg.enable or false) manifest.shares)
  ) hostManifests;
  hostsByShare = foldl' (
    acc: host:
    foldl' (
      shareAcc: share:
      shareAcc
      // {
        "${share}" = (shareAcc.${share} or [ ]) ++ [ host ];
      }
    ) acc hostEnabledShares.${host}
  ) { } (attrNames hostEnabledShares);

  # Peers = everyone except self
  peerIds = removeAttrs allDeviceIds [ hostname ];
  peerNames = attrNames peerIds;

  # Build syncthing device entries
  deviceEntries = mapAttrs (_: id: {
    inherit id;
    addresses = [ "dynamic" ];
  }) peerIds;

  # ── Secrets ──────────────────────────────────────────────────────────
  secretsRoot = ../../secrets;
  syncthingCertPath = secretsRoot + "/hosts/${hostname}/syncthing-cert.age";
  syncthingKeyPath = secretsRoot + "/hosts/${hostname}/syncthing-key.age";
  hasSyncthingSecrets = builtins.pathExists syncthingCertPath && builtins.pathExists syncthingKeyPath;

  enabledShares = lib.filterAttrs (_: shareCfg: shareCfg.enable) cfg.shares;

  # ── Share config ────────────────────────────────────────────────────
  # Hosts declare the shares they want via hosts/<name>/syncthing.nix.
  # A share automatically shares with every other host that requested the same
  # share name, unless an explicit shareWith override is provided.
  resolveShareDevices =
    name: shareCfg:
    if shareCfg.shareWith != null then
      filter (device: device != hostname) shareCfg.shareWith
    else if builtins.hasAttr name hostsByShare then
      filter (device: device != hostname) hostsByShare.${name}
    else
      peerNames;

  resolveSharePath =
    name: shareCfg:
    if shareCfg.path != null then
      shareCfg.path
    else
      throw "mountainous.features.syncthing.shares.${name} is enabled but no path is set";

  syncthingFolders = mapAttrs (
    name: shareCfg:
    {
      path = resolveSharePath name shareCfg;
      devices = resolveShareDevices name shareCfg;
      type = shareCfg.type;
      ignorePerms = shareCfg.ignorePerms;
      rescanIntervalS = shareCfg.rescanIntervalS;
    }
    // optionalAttrs (shareCfg.ignorePatterns != null) {
      inherit (shareCfg) ignorePatterns;
    }
    // optionalAttrs (shareCfg.versioning != null) {
      inherit (shareCfg) versioning;
    }
  ) enabledShares;
in {
  config = mkIf cfg.enable {
    assertions =
      mapAttrsToList (name: shareCfg: {
        assertion = shareCfg.path != null;
        message = "mountainous.features.syncthing.shares.${name} is enabled but no path is set";
      }) enabledShares
      ++ mapAttrsToList (name: shareCfg: {
        assertion =
          shareCfg.shareWith == null
          || all (device: builtins.elem device allDeviceNames) shareCfg.shareWith;
        message = "mountainous.features.syncthing.shares.${name}.shareWith contains an unknown device";
      }) enabledShares;

    services.syncthing = {
      enable = true;
      user = cfg.user;
      group = cfg.group;
      dataDir = cfg.dataDir;
      configDir = cfg.configDir;
      guiAddress = cfg.guiAddress;
      openDefaultPorts = cfg.openFirewall;

      cert = mkIf hasSyncthingSecrets config.age.secrets.syncthing-cert.path;
      key = mkIf hasSyncthingSecrets config.age.secrets.syncthing-key.path;

      overrideDevices = true;
      overrideFolders = true;

      settings = {
        devices = deviceEntries;
        folders = syncthingFolders;

        options = {
          urAccepted = -1;
          localAnnounceEnabled = true;
          globalAnnounceEnabled = true;
          relaysEnabled = true;
        };
      };
    };

    age.secrets = mkIf hasSyncthingSecrets {
      syncthing-cert = {
        file = syncthingCertPath;
        owner = cfg.user;
        group = cfg.group;
        mode = "400";
      };
      syncthing-key = {
        file = syncthingKeyPath;
        owner = cfg.user;
        group = cfg.group;
        mode = "400";
      };
    };

    boot.kernel.sysctl."fs.inotify.max_user_watches" = 524288;

    # The upstream NixOS module applies devices/folder settings through a oneshot
    # syncthing-init service. Ensure config changes on switch actually rerun it.
    systemd.services.syncthing-init = {
      restartIfChanged = true;
      stopIfChanged = true;
    };
  };
}
