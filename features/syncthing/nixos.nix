{
  config,
  lib,
  ...
}: let
  inherit (lib)
    mkDefault
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
  # Each host/device drops a `syncthing-device-id` file in its directory.
  # No cross-evaluation needed — just builtins.readFile on static data.

  hostsRoot = ../../hosts;
  devicesRoot = ../../devices;

  # Scan a directory for subdirs containing syncthing-device-id files
  discoverDevices =
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

  discoverHostShares =
    root:
    let
      entries = if builtins.pathExists root then builtins.readDir root else { };
      dirs = attrNames (lib.filterAttrs (_: type: type == "directory") entries);
      hasShares = name: builtins.pathExists (root + "/${name}/syncthing-shares.nix");
      withShares = filter hasShares dirs;
    in
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = import (root + "/${name}/syncthing-shares.nix");
      }) withShares
    );

  # All known devices: hosts + external devices (phones, etc.)
  allDeviceIds = (discoverDevices hostsRoot) // (discoverDevices devicesRoot);
  allDeviceNames = attrNames allDeviceIds;
  hostShareRequests = discoverHostShares hostsRoot;
  hostsByShare = foldl' (
    acc: host:
    foldl' (
      shareAcc: share:
      shareAcc
      // {
        "${share}" = (shareAcc.${share} or [ ]) ++ [ host ];
      }
    ) acc (attrNames hostShareRequests.${host})
  ) { } (attrNames hostShareRequests);

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

  # ── Folder config ───────────────────────────────────────────────────
  # Hosts declare the shares they want, plus their local paths, via
  # hosts/<name>/syncthing-shares.nix. A folder automatically shares with every
  # other host that requested the same folder name, unless an explicit
  # shareWith override is provided.
  resolveFolderDevices =
    name: folderCfg:
    if folderCfg.shareWith != null then
      filter (device: device != hostname) folderCfg.shareWith
    else if builtins.hasAttr name hostsByShare then
      filter (device: device != hostname) hostsByShare.${name}
    else
      peerNames;

  folders = mapAttrs (
    name: folderCfg:
    {
      path = folderCfg.path;
      devices = resolveFolderDevices name folderCfg;
      type = folderCfg.type;
      ignorePerms = folderCfg.ignorePerms;
      rescanIntervalS = folderCfg.rescanIntervalS;
    }
    // optionalAttrs (folderCfg.ignorePatterns != null) {
      inherit (folderCfg) ignorePatterns;
    }
    // optionalAttrs (folderCfg.versioning != null) {
      inherit (folderCfg) versioning;
    }
  ) cfg.folders;
in {
  config = mkIf cfg.enable {
    assertions = mapAttrsToList (name: folderCfg: {
      assertion =
        folderCfg.shareWith == null
        || all (device: builtins.elem device allDeviceNames) folderCfg.shareWith;
      message = "mountainous.features.syncthing.folders.${name}.shareWith contains an unknown device";
    }) cfg.folders;

    # Default folders — hosts can override with mkForce or add more
    mountainous.features.syncthing.folders = {
      pi-config = {
        path = mkDefault "/home/${cfg.user}/.pi";
        ignorePatterns = mkDefault [
          "**/.git"
          "**/.git/**"
          "**/node_modules"
          "**/node_modules/**"
          "**/.direnv"
          "**/.direnv/**"
          "**/.venv"
          "**/.venv/**"
          "**/venv"
          "**/venv/**"
          "**/__pycache__"
          "**/__pycache__/**"
          "**/.mypy_cache"
          "**/.mypy_cache/**"
          "**/.pytest_cache"
          "**/.pytest_cache/**"
          "**/.ruff_cache"
          "**/.ruff_cache/**"
          "**/.cache"
          "**/.cache/**"
          "**/dist"
          "**/dist/**"
          "**/build"
          "**/build/**"
          "**/result"
          "**/result/**"
          "**/tmp"
          "**/tmp/**"
          "**/.tmp"
          "**/.tmp/**"
          "**/agent/bin"
          "**/agent/bin/**"
          "**/*.log"
        ];
      };

      biometrics.path = mkDefault "/home/${cfg.user}/biometrics";
      fitness.path = mkDefault "/home/${cfg.user}/fitness";
      flakey.path = mkDefault "/home/${cfg.user}/flakey";
      omi.path = mkDefault "/home/${cfg.user}/omi";
      research.path = mkDefault "/home/${cfg.user}/research";
      therapy.path = mkDefault "/home/${cfg.user}/therapy";
      transcripts.path = mkDefault "/home/${cfg.user}/transcripts";
      nutrition.path = mkDefault "/home/${cfg.user}/.local/share/nutrition";
      tasks.path = mkDefault "/home/${cfg.user}/.local/share/tasks";
    };

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
        inherit folders;

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

    # The upstream NixOS module applies devices/folders through a oneshot
    # syncthing-init service. Ensure config changes on switch actually rerun it.
    systemd.services.syncthing-init = {
      restartIfChanged = true;
      stopIfChanged = true;
    };
  };
}
