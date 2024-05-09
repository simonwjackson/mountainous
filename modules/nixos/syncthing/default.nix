{
  config,
  pkgs,
  lib,
  target,
  ...
}: let
  findHosts = arch:
    lib.flatten (lib.mapAttrsToList
      (host: _:
        lib.optional (builtins.pathExists ../../../systems/${arch}/${host}/syncthing.nix) {
          name = host;
          arch = arch;
        })
      (builtins.readDir ../../../systems/${arch}));

  hosts = findHosts "x86_64-linux" ++ findHosts "aarch64-linux";

  importSyncthingConfig = host: arch: (import ../../../systems/${arch}/${host}/syncthing.nix {inherit config host;});

  syncthingConfigs = builtins.listToAttrs (map (host: {
      name = host.name;
      value = importSyncthingConfig host.name host.arch;
    })
    hosts);

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
  services.syncthing = {
    overrideDevices = true;
    overrideFolders = true;
    user = config.mountainous.user.name;
    configDir = "/home/${config.mountainous.user.name}/.config/syncthing";

    settings = {
      ignores.line = [
        "**/node_modules"
        "**/build"
        "**/cache"
      ];

      folders = lib.mkMerge (getHostFolders
        (import ../../../systems/${target}/${config.networking.hostName}/syncthing.nix {
          inherit config;
          host = "${config.networking.hostName}";
        })
        .paths);

      devices = lib.mapAttrs (name: config: config.device) syncthingConfigs;
    };

    extraFlags = [
      "--no-default-folder"
      # "--gui-address=0.0.0.0:8384"
    ];
  };
}
