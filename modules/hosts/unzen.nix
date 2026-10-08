# Intel i7-9700K / ASRock Z390 Phantom Gaming-ITX/ac headless server.
# Storage is deliberately incomplete until an initial install layout is approved.
{
  nixos.hosts.unzen = {
    system = "x86_64-linux";
    layers = [
      "base"
      "server"
    ];

    module = {
      hardware.cpu.intel.updateMicrocode = true;
      boot.supportedFilesystems = [ "bcachefs" ];

      # The shared disk layer formats btrfs. Do not import it or guess devices
      # for this bcachefs host. Root, boot, and the pool need a separate plan.

      # Both 95 W limits completed the staged CPU + read-only SSD test.
      # No voltage offsets, temperature targets, or turbo override are set.
      services.undervolt = {
        enable = true;
        # Required by the upstream options. These encode the existing
        # 27983872 / 2440 us sysfs windows, rather than selecting new ones.
        p1 = {
          limit = 95;
          window = 28;
        };
        p2 = {
          limit = 95;
          window = 0.00244;
        };
      };
    };
  };
}
