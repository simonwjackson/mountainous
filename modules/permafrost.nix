# The permafrost layer: a host whose system root is wiped at every boot.
#
# `/` is a tmpfs. Only the btrfs subvolumes in disks/permafrost.nix survive:
# /nix, /home, /permafrost and /var/lib/tailscale. Anything an agent or a
# person changes outside them, by hand, is gone after the next reboot, so the
# flake is the only description of the machine.
#
# Losing Tailscale's state locks a remote host out (see
# docs/plans/yari-forgerie-host.md), so its protection does not depend on
# a copy step that can be forgotten:
#
#   - /var/lib/tailscale is a subvolume mounted at its real path
#   - tailscaled requires that mount, so it never starts on the empty tmpfs
#     and creates a new identity there
#   - the SSH host key, from which sops derives its age key, is read straight
#     from /permafrost, which is mounted in the initrd before sops runs
{
  inputs,
  lib,
  ...
}:
let
  hostKey = "/permafrost/etc/ssh/ssh_host_ed25519_key";

  module =
    {
      config,
      lib,
      options,
      ...
    }:
    let
      cfg = config.mountainous.permafrost;
      inherit (lib) mkOption types;
    in
    {
      imports = [
        inputs.disko.nixosModules.disko
        (inputs.impermanence + "/nixos.nix")
      ];

      options.mountainous.permafrost = {
        device = mkOption {
          type = types.str;
          description = ''
            The whole disk to partition at install. Everything on it is
            destroyed. Use a /dev/disk/by-id/ path.
          '';
        };

        rootSize = mkOption {
          type = types.str;
          default = "4G";
          description = ''
            Size cap of the tmpfs root. A runaway write outside the persisted
            paths fails at this size instead of taking memory from services.
            /tmp is a separate tmpfs (boot.tmp.useTmpfs in base.nix).
          '';
        };
      };

      config = lib.mkMerge [
        (import ../disks/permafrost.nix { inherit (cfg) device rootSize; })

        {
          fileSystems."/permafrost".neededForBoot = true;

          environment.persistence."/permafrost" = {
            hideMounts = true;
            directories = [
              # Stable UID and GID allocation across rebuilds.
              "/var/lib/nixos"
              # Logs from a failed boot are the logs you need most.
              "/var/log"
              "/var/lib/systemd/timers"
              "/var/lib/systemd/coredump"
            ];
            # Keeps journal continuity: journals live under /var/log/journal/<machine-id>.
            files = [ "/etc/machine-id" ];
          };

          # Read the host key in place. No bind mount has to exist before sshd
          # or sops can find it.
          services.openssh.hostKeys = lib.mkForce [
            {
              type = "ed25519";
              path = hostKey;
            }
          ];

          systemd.services.tailscaled = lib.mkIf config.services.tailscale.enable {
            unitConfig.RequiresMountsFor = [ "/var/lib/tailscale" ];
          };

          assertions = [
            {
              assertion = (config.fileSystems."/var/lib/tailscale".fsType or null) == "btrfs";
              message = "permafrost: /var/lib/tailscale must be its own btrfs subvolume.";
            }
            {
              assertion = (config.fileSystems."/".fsType or null) == "tmpfs";
              message = "permafrost: / must be a tmpfs.";
            }
          ];
        }

        # sops is in the base layer, not in the VM test. Set its key path only
        # where the option exists.
        (lib.optionalAttrs (options ? sops) {
          sops.age.sshKeyPaths = lib.mkForce [ hostKey ];
        })
      ];
    };
in
{
  nixos.modules.permafrost = module;

  perSystem =
    { pkgs, system, ... }:
    # The VM test needs KVM, which only the x86_64 machines have.
    lib.mkIf (system == "x86_64-linux") {
      checks.permafrost = import ../tests/permafrost.nix {
        inherit pkgs inputs;
        permafrost = module;
      };
    };
}
