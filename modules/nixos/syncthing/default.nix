{
  config,
  pkgs,
  lib,
  options,
  target,
  ...
}: let
  inherit (lib.mountainous) enabled;

  cfg = config.mountainous.syncthing;

  systems = ../../../systems;
  architectures = builtins.attrNames (builtins.readDir systems);

  getHosts = arch: builtins.attrNames (builtins.readDir (systems + "/${arch}"));

  importSyncthingConfig = arch: host: let
    syncthingPath = systems + "/${arch}/${host}/syncthing.nix";
  in
    if builtins.pathExists syncthingPath
    then import syncthingPath {inherit config host;}
    else null;

  syncthingConfigs = builtins.listToAttrs (builtins.concatMap (
      arch:
        builtins.filter (item: item != null) (map (
          host: let
            config = importSyncthingConfig arch host;
          in
            if config != null
            then {
              name = host;
              value = config;
            }
            else null
        ) (getHosts arch))
    )
    architectures);

  getFolderDevices = name:
    lib.flatten (lib.mapAttrsToList
      (hostName: config: lib.optionals (config.paths ? "${name}") [hostName])
      syncthingConfigs);

  getHostFolders =
    lib.mapAttrsToList
    (name: value: {
      "${name}" = {
        path = value;
        devices = getFolderDevices name;
      };
    });
in {
  options.mountainous.syncthing =
    {
      enable = lib.mkEnableOption "Whether to enable syncthing";
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

        folders =
          lib.mkMerge (getHostFolders
            (importSyncthingConfig target config.networking.hostName).paths);

        devices = lib.mapAttrs (name: config: config.device) syncthingConfigs;
      };

      extraFlags = [
        "--no-default-folder"
        # "--gui-address=0.0.0.0:8384"
      ];
    };
  };
}
