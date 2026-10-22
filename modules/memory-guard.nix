# The memory guard: no host may lock you out by running out of memory.
#
# Zram alone made a memory spike slow a machine down instead of killing
# anything. On a headless machine that is a lockout: sshd and tailscaled are
# swapped out with everything else, and the kernel OOM killer acts only after
# RAM and swap are both full. Zao, 2026-10-22: a `nix flake check` reached
# 14.8 GiB RAM plus 9.1 GiB swap before the kernel killed it.
#
# Four rules, on every host:
#   - sshd and tailscaled keep their memory (MemoryMin). The protection only
#     works up to what the parent protects, so system.slice reserves it too.
#     No OOMScoreAdjust: children inherit it, and every SSH login starts as a
#     child of sshd or tailscaled.
#   - systemd-oomd watches system.slice and kills the cgroup that causes
#     sustained memory pressure, usually nix-daemon with its builds.
#   - nix-daemon has MemoryHigh and MemoryMax, so builds slow down and then
#     fail instead of starving the machine.
#   - Builds use /nix/var/nix/builds, on the same disk as the store, not the
#     tmpfs /tmp, where every build tree would be held in RAM.
#
# Headless hosts also let oomd watch the user slices, where an evaluation
# such as `nix flake check` runs. The desktop layer turns that off: Hyprland
# and every terminal it starts share one session scope, and oomd would end
# the whole desktop.
let
  guard =
    { config, lib, ... }:
    let
      cfg = config.mountainous.memoryGuard;
    in
    {
      options.mountainous.memoryGuard = {
        userSlices = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Let systemd-oomd kill cgroups under user slices on sustained memory pressure.";
        };
        nixDaemon = {
          memoryHigh = lib.mkOption {
            type = lib.types.str;
            default = "75%";
            description = "nix-daemon's MemoryHigh: above it, builds are slowed and reclaimed.";
          };
          memoryMax = lib.mkOption {
            type = lib.types.str;
            default = "85%";
            description = "nix-daemon's MemoryMax: the kernel ends builds above it.";
          };
        };
        buildDir = lib.mkOption {
          type = lib.types.str;
          default = "/nix/var/nix/builds";
          description = "Where builds unpack and compile. Must be on disk, not tmpfs.";
        };
      };

      config = {
        systemd.slices.system.sliceConfig.MemoryMin = "512M";
        systemd.services.sshd.serviceConfig.MemoryMin = "64M";
        systemd.services.tailscaled.serviceConfig.MemoryMin =
          lib.mkIf config.services.tailscale.enable "256M";

        systemd.oomd = {
          enable = true;
          enableSystemSlice = true;
          enableUserSlices = cfg.userSlices;
        };

        systemd.services.nix-daemon = {
          serviceConfig = {
            MemoryHigh = cfg.nixDaemon.memoryHigh;
            MemoryMax = cfg.nixDaemon.memoryMax;
          };
          environment.TMPDIR = cfg.buildDir;
        };
        systemd.tmpfiles.rules = [ "d ${cfg.buildDir} 0755 root root 7d" ];
      };
    };
in
{
  nixos.modules.base = guard;
  # For tests: tests/build-federation-vm.nix runs the real module.
  flake.lib.memoryGuardModule = guard;

  nixos.modules.desktop =
    { lib, ... }:
    {
      mountainous.memoryGuard.userSlices = lib.mkDefault false;
    };
}
