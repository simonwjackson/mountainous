{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types mkIf mkMerge mapAttrs' mapAttrs nameValuePair concatStringsSep;

  cfg = config.services.nfsAutofsModule;

  genAutoFiles =
    mapAttrs' (
      name: host:
        nameValuePair "auto.${name}" {
          text = ''
            nfs    -fstype=autofs    :/etc/auto.${name}.nfs
          '';
          mode = "0644";
        }
    )
    cfg.hosts;

  genAutoNfsFiles =
    mapAttrs' (
      name: host:
        nameValuePair "auto.${name}.nfs" {
          text = ''
            ${host.shareName}    -fstype=nfs,rw,soft,intr    ${host.hostname}:/${host.shareName}
          '';
          mode = "0644";
        }
    )
    cfg.hosts;
in {
  options.services.nfsAutofsModule = {
    enable = mkEnableOption "NFS and AutoFS configuration";

    timeout = mkOption {
      type = types.int;
      default = 10;
      description = "Timeout for AutoFS in seconds";
    };

    hosts = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          hostname = mkOption {
            type = types.str;
            description = "Hostname for NFS server";
          };
          shareName = mkOption {
            type = types.str;
            description = "Name of the NFS share";
          };
        };
      });
      default = {};
      description = "Hostnames and share names for NFS mounts";
    };

    ipRanges = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "IP ranges for NFS exports";
    };
  };

  config = mkIf cfg.enable {
    services.autofs = {
      enable = true;
      autoMaster = ''
        /net    /etc/auto.net    --timeout=${toString cfg.timeout} --ghost
      '';
    };

    environment.etc = mkMerge [
      {
        "auto.net" = {
          text = ''
            *    -fstype=autofs    :/etc/auto.&
          '';
          mode = "0644";
        };
      }
      genAutoFiles
      genAutoNfsFiles
    ];

    environment.systemPackages = [pkgs.nfs-utils pkgs.mergerfs];
    services.rpcbind.enable = true;

    services.nfs.server = {
      enable = true;
      exports = ''
        /snowscape 127.0.0.0/8(rw,sync,no_subtree_check,fsid=0,crossmnt) ${concatStringsSep " " (map (range: "${range}(rw,sync,no_subtree_check,fsid=0,crossmnt)") cfg.ipRanges)}
      '';
    };
  };
}
