{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mapAttrsToList all;

  cfg = config.mountainous.features.syncthing;
  hostname = config.networking.hostName;

  syncLib = import ./lib.nix {inherit lib;};
  syncConfig = syncLib.mkSyncConfig {
    hostsRoot = ../../hosts;
    devicesRoot = ../../devices;
    inherit hostname;
    shares = cfg.shares;
  };

  inherit (syncConfig) deviceEntries enabledShares allDeviceNames syncthingFolders;

  # ── Secrets ──────────────────────────────────────────────────────────
  secretsRoot = ../../secrets;
  syncthingCertPath = secretsRoot + "/hosts/${hostname}/syncthing-cert.age";
  syncthingKeyPath = secretsRoot + "/hosts/${hostname}/syncthing-key.age";
  hasSyncthingSecrets = builtins.pathExists syncthingCertPath && builtins.pathExists syncthingKeyPath;
in {
  config = mkIf cfg.enable {
    assertions =
      mapAttrsToList (name: shareCfg: {
        assertion = shareCfg.path != null;
        message = "mountainous.features.syncthing.shares.${name} is enabled but no path is set";
      })
      enabledShares
      ++ mapAttrsToList (name: shareCfg: {
        assertion =
          shareCfg.shareWith
          == null
          || all (device: builtins.elem device allDeviceNames) shareCfg.shareWith;
        message = "mountainous.features.syncthing.shares.${name}.shareWith contains an unknown device";
      })
      enabledShares;

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

    # Override auto-discovered ownership to match the syncthing service user.
    age.secrets = mkIf hasSyncthingSecrets {
      syncthing-cert = {
        owner = cfg.user;
        group = cfg.group;
      };
      syncthing-key = {
        owner = cfg.user;
        group = cfg.group;
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
