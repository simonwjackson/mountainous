{lib}: let
  inherit (lib) attrNames filter filterAttrs foldl' mapAttrs optionalAttrs;

  discoverHostManifests = root: let
    entries =
      if builtins.pathExists root
      then builtins.readDir root
      else {};
    dirs = attrNames (filterAttrs (_: type: type == "directory") entries);
    hasManifest = name: builtins.pathExists (root + "/${name}/syncthing.nix");
    withManifests = filter hasManifest dirs;
  in
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = import (root + "/${name}/syncthing.nix");
      })
      withManifests
    );

  discoverExternalDevices = root: let
    entries =
      if builtins.pathExists root
      then builtins.readDir root
      else {};
    dirs = attrNames (filterAttrs (_: type: type == "directory") entries);
    hasId = name: builtins.pathExists (root + "/${name}/syncthing-device-id");
    withIds = filter hasId dirs;
  in
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = lib.removeSuffix "\n" (builtins.readFile (root + "/${name}/syncthing-device-id"));
      })
      withIds
    );
in {
  mkSyncConfig = {
    hostsRoot,
    devicesRoot,
    hostname,
    shares,
  }: let
    hostManifests = discoverHostManifests hostsRoot;

    allDeviceIds =
      (mapAttrs (_: m: m.deviceId) hostManifests)
      // (discoverExternalDevices devicesRoot);
    allDeviceNames = attrNames allDeviceIds;

    hostEnabledShares = mapAttrs (
      _: m:
        attrNames (filterAttrs (_: s: s.enable or false) m.shares)
    ) hostManifests;

    hostsByShare = foldl' (
      acc: host:
        foldl' (
          sAcc: share:
            sAcc // {"${share}" = (sAcc.${share} or []) ++ [host];}
        )
        acc
        hostEnabledShares.${host}
    ) {} (attrNames hostEnabledShares);

    peerIds = builtins.removeAttrs allDeviceIds [hostname];
    peerNames = attrNames peerIds;

    deviceEntries = mapAttrs (_: id: {
      inherit id;
      addresses = ["dynamic"];
    }) peerIds;

    enabledShares = filterAttrs (_: s: s.enable) shares;

    resolveShareDevices = name: shareCfg:
      if shareCfg.shareWith != null
      then filter (d: d != hostname) shareCfg.shareWith
      else if builtins.hasAttr name hostsByShare
      then filter (d: d != hostname) hostsByShare.${name}
      else peerNames;

    resolveSharePath = name: shareCfg:
      if shareCfg.path != null
      then shareCfg.path
      else throw "mountainous.features.syncthing.shares.${name} is enabled but no path is set";

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
    inherit
      allDeviceIds
      allDeviceNames
      deviceEntries
      enabledShares
      hostsByShare
      peerIds
      peerNames
      syncthingFolders
      ;
  };
}
