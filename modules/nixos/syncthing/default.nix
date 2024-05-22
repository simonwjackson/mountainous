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

  hostListFromOtherDevices = devices: lib.mapAttrs (name: value: {id = value.device.id;}) devices;
  hostListFromSystemConfigs = configs: lib.mapAttrs (name: config: config.device) configs;

  devices =
    (hostListFromSystemConfigs allSyncthingConfigs)
    // (hostListFromOtherDevices cfg.otherDevices);

  getSyncthingConfig = arch: host: let
    syncthingPath = get-file "systems/${arch}/${host}/syncthing.nix";
  in
    if builtins.pathExists syncthingPath
    then import syncthingPath {inherit config host;}
    else null;

  allSyncthingConfigs = builtins.listToAttrs (builtins.concatMap (
      arch:
        builtins.filter (item: item != null) (map (
          host: let
            config = getSyncthingConfig arch host;
          in
            if config != null
            then {
              name = host;
              value = config;
            }
            else null
        ) (getAllHosts arch))
    )
    allArchitectures);

  getFolderDevices = name:
    lib.flatten (lib.mapAttrsToList
      (hostName: config: lib.optionals (config.paths ? "${name}") [hostName])
      allSyncthingConfigs);

  getDevicesWithFolder = devices: folder: let
    hasFolder = device: builtins.elem folder device.folders;
  in
    builtins.attrNames (lib.filterAttrs (name: device: hasFolder device) devices);

  getHostFolders =
    lib.mapAttrsToList
    (name: value: {
      "${name}" = {
        path = value;
        devices = getFolderDevices name ++ (getDevicesWithFolder cfg.otherDevices name);
      };
    });

  foldersFromHost = host: lib.mkMerge (getHostFolders (getSyncthingConfig target host).paths);
in {
  options.mountainous.syncthing =
    {
      enable = lib.mkEnableOption "Whether to enable syncthing";

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
            folders = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "List of folder names to sync with the device";
            };
          };
        });
        default = {};
        description = "Configuration for other Syncthing devices";
      };
    }
    // options.services.syncthing;

  config = lib.mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      overrideDevices = true;
      overrideFolders = true;
      key = cfg.key;
      cert = cfg.cert;
      user = config.mountainous.user.name;
      configDir = "/home/${config.mountainous.user.name}/.config/syncthing";

      settings = {
        ignores.line = [
          "**/node_modules"
          "**/build"
          "**/cache"
        ];

        folders = foldersFromHost config.networking.hostName;

        inherit devices;
      };

      extraFlags = [
        "--no-default-folder"
        # "--gui-address=0.0.0.0:8384"
      ];
    };
  };
}
