# The memory guard: no host may lock you out by running out of memory.
#
# The same standard as cairn's modules/memory-guard.nix. Keep the two equal
# until Zao and Aka move to cairn.
#
# Zram alone made a memory spike slow a machine down instead of killing
# anything. On a headless machine that is a lockout: sshd and tailscaled are
# swapped out with everything else, and the kernel OOM killer acts only after
# RAM and swap are both full. Zao, 2026-10-22: a `nix flake check` reached
# 14.8 GiB RAM plus 9.1 GiB swap before the kernel killed it.
#
#   - sshd and tailscaled keep their memory (MemoryMin); system.slice reserves
#     it too, or the reserve below it does nothing. No OOMScoreAdjust: every
#     SSH login is a child of sshd or tailscaled and would inherit it.
#   - systemd-oomd watches system.slice and kills the cgroup that causes
#     sustained memory pressure, usually nix-daemon with its builds.
#   - nix-daemon has MemoryHigh and MemoryMax.
#   - Builds unpack on disk (/nix/var/nix/builds), never in a tmpfs.
{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.mountainous.features.memory-guard;
in {
  options.mountainous.features.memory-guard = {
    enable = mkEnableOption "the fleet memory guard";
    userSlices = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Let systemd-oomd kill cgroups under user slices. Off where a game or a
        desktop session runs in a user slice and must not be the one killed.
      '';
    };
    nixDaemon = {
      memoryHigh = mkOption {
        type = types.str;
        default = "75%";
      };
      memoryMax = mkOption {
        type = types.str;
        default = "85%";
      };
    };
    buildDir = mkOption {
      type = types.str;
      default = "/nix/var/nix/builds";
    };
  };

  config = mkIf cfg.enable {
    systemd.slices.system.sliceConfig.MemoryMin = "512M";
    systemd.services.sshd.serviceConfig.MemoryMin = "64M";
    systemd.services.tailscaled.serviceConfig.MemoryMin = mkIf config.services.tailscale.enable "256M";

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
    systemd.tmpfiles.rules = ["d ${cfg.buildDir} 0755 root root 7d"];
  };
}
