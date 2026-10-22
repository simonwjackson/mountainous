# Two wired ports as one NetworkManager active-backup bond: the primary port
# carries all traffic and the backup takes over within a second if the
# primary loses link. No switch support is needed and port speeds may differ.
# The bond gets its address by DHCP.
{ ... }:
let
  lanBond =
    { config, lib, ... }:
    let
      cfg = config.mountainous.features.lan-bond;
      port = name: {
        connection = {
          id = "bond0-${name}";
          type = "ethernet";
          interface-name = name;
          controller = "bond0";
          port-type = "bond";
          autoconnect = true;
          autoconnect-priority = 10;
        };
      };
    in
    {
      options.mountainous.features.lan-bond = {
        enable = lib.mkEnableOption "an active-backup bond of two wired ports";
        primary = lib.mkOption {
          type = lib.types.str;
          description = "Port that carries traffic whenever it has link.";
        };
        backup = lib.mkOption {
          type = lib.types.str;
          description = "Port that takes over when the primary loses link.";
        };
      };
      config = lib.mkIf cfg.enable {
        networking.networkmanager = {
          enable = true;
          # No per-port "Wired connection" profiles competing with the bond.
          settings.main.no-auto-default = "interface-name:${cfg.primary},interface-name:${cfg.backup}";
          ensureProfiles.profiles = {
            bond0 = {
              connection = {
                id = "bond0";
                type = "bond";
                interface-name = "bond0";
                autoconnect = true;
                autoconnect-priority = 10;
                autoconnect-ports = 1;
              };
              bond = {
                mode = "active-backup";
                inherit (cfg) primary;
                miimon = "100";
              };
              ipv4.method = "auto";
              ipv6 = {
                method = "auto";
                addr-gen-mode = "stable-privacy";
              };
            };
            "bond0-${cfg.primary}" = port cfg.primary;
            "bond0-${cfg.backup}" = port cfg.backup;
          };
        };
      };
    };
in
{
  nixos.modules.server.imports = [ lanBond ];
  perSystem =
    { pkgs, lib, ... }:
    {
      checks = lib.optionalAttrs pkgs.stdenv.hostPlatform.isx86_64 {
        lan-bond-vm = import ../tests/lan-bond-vm.nix {
          inherit pkgs;
          bondModule = lanBond;
        };
      };
    };
}
