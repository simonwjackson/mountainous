{
  config,
  pkgs,
  lib,
  options,
  target,
  ...
}: let
  inherit (lib.mountainous) enabled;
  inherit (lib.mountainous.util) allArchitectures getAllHosts;
  inherit (lib.snowfall.fs) get-file;

  cfg = config.mountainous.syncthing;

  importConfigIfExists = configPath: host:
    if builtins.pathExists configPath
    then import configPath {inherit config host;}
    else null;

  createNamedConfig = importConfigFn: architecture: hostname: let
    importedConfig = importConfigFn architecture hostname;
  in
    if importedConfig != null
    then {
      name = hostname;
      value = importedConfig;
    }
    else null;

  getConfigsForArchitecture = importConfigFn: architecture: let
    hostsForArch = getAllHosts cfg.systemsDir architecture;
    archConfigs = map (createNamedConfig importConfigFn architecture) hostsForArch;
  in
    builtins.filter (item: item != null) archConfigs;

  getAllArchitectureConfigs = importConfigFn: let
    architectures = allArchitectures cfg.systemsDir;
    allArchConfigs = builtins.concatMap (getConfigsForArchitecture importConfigFn) architectures;
  in
    allArchConfigs;

  importSyncthingConfig = architecture: hostname:
    importConfigIfExists "${cfg.systemsDir}/${architecture}/${hostname}/syncthing.nix" hostname;

  allSyncthingConfigs = builtins.listToAttrs (getAllArchitectureConfigs importSyncthingConfig);

  deviceHasShare = shareName: deviceConfig: deviceConfig.shares ? "${shareName}";

  getDevicesWithShare = shareName:
    lib.mapAttrsToList
    (deviceName: deviceConfig:
      if deviceHasShare shareName deviceConfig
      then [deviceName]
      else []);

  getDevicesForShare = shareName:
    lib.flatten (getDevicesWithShare shareName allSyncthingConfigs);

  filterDevicesByShare = shareName:
    lib.filterAttrs
    (deviceName: deviceConfig: builtins.elem shareName deviceConfig.shares);

  getDeviceNamesForShare = shareName: devices:
    builtins.attrNames (filterDevicesByShare shareName devices);

  createShareConfig = lib.mapAttrsToList (shareName: shareConfig: {
    "${shareName}" =
      shareConfig
      // {
        devices = getDevicesForShare shareName ++ (getDeviceNamesForShare shareName cfg.otherDevices);
      };
  });

  getArchConfigs = arch: let
    hosts = getAllHosts cfg.systemsDir arch;
    configs = map (createNamedConfig arch) hosts;
  in
    builtins.filter (item: item != null) configs;

  getAllArchConfigs = let
    archs = allArchitectures cfg.systemsDir;
    allConfigs = builtins.concatMap getArchConfigs archs;
  in
    allConfigs;

  isDeviceInShare = shareName: config:
    config.shares ? "${shareName}";

  deviceListFromOthers = lib.mapAttrs (name: value: {id = value.device.id;}) cfg.otherDevices;

  deviceListFromSystems = lib.mapAttrs (name: config: config.device) allSyncthingConfigs;

  sharesFromHost = host:
    lib.mkMerge (createShareConfig
      (importSyncthingConfig target host).shares);

  generateActivationScript = shares: let
    filteredShares = let
      contents = shares.contents or [];
      hasListType = item: name:
        lib.hasAttrByPath [(builtins.head (builtins.attrNames item)) name] item
        && (builtins.getAttr name (builtins.getAttr (builtins.head (builtins.attrNames item)) item)) != false;

      filteredContents = lib.filter (item: hasListType item "whitelist" || hasListType item "blacklist") contents;
    in
      filteredContents;

    getFirstKey = item: builtins.head (builtins.attrNames item);

    scriptForShare = item: let
      key = getFirstKey item;
      value = builtins.getAttr key item;
      isWhitelist = value ? whitelist;
      listType =
        if isWhitelist
        then "whitelist"
        else "blacklist";
      list = value.${listType};

      generateListContent = list:
        if builtins.isBool list
        then "*"
        else let
          listLines =
            if isWhitelist
            then map (line: "!${line}") list ++ ["*"]
            else list;
        in
          builtins.concatStringsSep "\n" listLines;
    in ''
      STIGNORE_PATH="${value.path}/.stignore"

      # Create or update .stignore file
      ${
        if builtins.isBool list
        then ''
          if [ -f "$STIGNORE_PATH" ]; then
            if ! ${pkgs.gnugrep}/bin/grep -q '^[*]$' "$STIGNORE_PATH"; then
              echo '*' >> "$STIGNORE_PATH"
              echo "Added '*' to $STIGNORE_PATH"
            fi
          else
            echo '*' > "$STIGNORE_PATH"
            echo "Created $STIGNORE_PATH with '*'"
          fi
        ''
        else ''
          cat > "$STIGNORE_PATH" << EOL
          ${generateListContent list}
          EOL
          echo "Updated $STIGNORE_PATH with ${listType} patterns"
        ''
      }
    '';

    scripts = map scriptForShare filteredShares;
  in
    builtins.concatStringsSep "\n" scripts;
in {
  # Options
  options.mountainous.syncthing =
    options.services.syncthing
    // {
      otherDevices = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            device = lib.mkOption {
              type = lib.types.submodule {
                options.id = lib.mkOption {
                  type = lib.types.str;
                  description = "Device ID";
                };
              };
              description = "Syncthing device configuration";
            };
            shares = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "List of share names to sync with the device";
            };
          };
        });
        default = {};
        description = "Configuration for other Syncthing devices";
      };

      systemsDir = lib.mkOption {
        type = lib.types.path;
        description = "Directory containing system configurations";
      };

      user = lib.mkOption {
        type = lib.types.str;
        # default = config.mountainous.user.name;
        default = "simonwjackson";
        description = "User running Syncthing";
      };

      hostName = lib.mkOption {
        type = lib.types.str;
        default = config.networking.hostName;
        description = "Hostname for the current system";
      };
    };

  # Configuration
  config = lib.mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      overrideDevices = true;
      overrideFolders = true;
      key = cfg.key;
      cert = cfg.cert;
      user = cfg.user;
      configDir = "/home/${cfg.user}/.config/syncthing";

      settings = {
        ignores.line = [
          "**/node_modules"
          "**/build"
          "**/cache"
        ];

        folders = sharesFromHost cfg.hostName;
        devices = deviceListFromSystems // deviceListFromOthers;
      };

      extraFlags = [
        "--no-default-folder"
        # "--gui-address=0.0.0.0:8384"
      ];
    };

    system.activationScripts.syncthingStignore = {
      supportsDryActivation = true;
      text = let
        shares = sharesFromHost cfg.hostName;
        script = generateActivationScript shares;
      in ''
        if [ "$NIXOS_ACTION" = "dry-activate" ]; then
          echo "Would ensure the .stignore files are updated for whitelisted and blacklisted Syncthing shares"
        else
          ${script}
          : # noop
        fi
      '';
    };

    # Assert that whitelist and blacklist are not used simultaneously
    assertions = [
      {
        assertion = let
          shares = sharesFromHost cfg.hostName;
          hasWhitelistAndBlacklist = item:
            lib.hasAttrByPath [(builtins.head (builtins.attrNames item)) "whitelist"] item
            && lib.hasAttrByPath [(builtins.head (builtins.attrNames item)) "blacklist"] item;
          conflictingShares = builtins.filter hasWhitelistAndBlacklist (shares.contents or []);
        in
          builtins.length conflictingShares == 0;
        message = "Cannot use both whitelist and blacklist for the same Syncthing share";
      }
    ];
  };
}
