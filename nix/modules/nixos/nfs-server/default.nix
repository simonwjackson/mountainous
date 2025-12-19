{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types concatStringsSep;
  cfg = config.mountainous.nfs-server;

  # Build exports string from structured configuration
  buildExportsLine = export: let
    optionsStr = concatStringsSep "," export.options;
  in "${export.path} ${export.clients}(${optionsStr})";

  exportsContent = concatStringsSep "\n" (map buildExportsLine cfg.exports);

  # Export entry submodule type
  exportType = types.submodule {
    options = {
      path = mkOption {
        type = types.str;
        description = "Local path to export";
        example = "/home/user/.local/share/Steam";
      };

      clients = mkOption {
        type = types.str;
        default = "100.64.0.0/10";
        description = ''
          Client specification (IP, CIDR, hostname pattern).
          Default is Tailscale CGNAT range.
        '';
        example = "192.168.1.0/24";
      };

      options = mkOption {
        type = types.listOf types.str;
        default = ["rw" "sync" "no_subtree_check" "crossmnt" "no_root_squash"];
        description = "NFS export options";
        example = ["rw" "sync" "all_squash" "anonuid=1000" "anongid=1000"];
      };
    };
  };
in {
  options.mountainous.nfs-server = {
    enable = mkEnableOption "NFS server for sharing directories";

    exports = mkOption {
      type = types.listOf exportType;
      default = [];
      description = "List of directories to export via NFS";
      example = [
        {
          path = "/home/user/.local/share/Steam";
          clients = "100.64.0.0/10";
          options = ["rw" "sync" "no_subtree_check" "all_squash" "anonuid=333" "anongid=333"];
        }
      ];
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open firewall ports for NFS (2049 TCP/UDP)";
    };
  };

  config = mkIf cfg.enable {
    services.nfs.server = {
      enable = true;
      exports = exportsContent;
    };

    # Open firewall for NFS
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [2049];
      allowedUDPPorts = [2049];
    };
  };
}
