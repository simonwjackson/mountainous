# The laptop, on its own internal disk.
#
# This host exists before the machine does. It builds today, which proves the
# desktop and the layers evaluate, and it deliberately cannot install today,
# which is the safe half of that trade.
#
# Two facts are missing, and both are marked REPLACE below:
#
#   1. cairn.disk.device -- the real drive, as a by-id path.
#   2. a hardware layer, if the machine needs one.
#
# Nothing else should change when the laptop arrives. myoko and hiyori import
# the same base and desktop, so the environment is the same setup by
# construction rather than by copying.
#
# myoko needs no `portable` layer and no bootloader block. `base` already
# defaults to systemd-boot with canTouchEfiVariables, which is exactly what a
# machine that stays in one place wants. `portable` is the deviation from that
# default, not the other way round.
{
  nixos.hosts.myoko = {
    system = "aarch64-linux";
    layers = [
      "base"
      "desktop"
      "disk"

      # REPLACE (2): add a hardware layer once the model is known.
      #
      # If it is another Galaxy Book3 Pro 360, add "galaxy-book3" and nothing
      # else. If it is a different machine, copy that file's shape: firmware,
      # microcode, graphics, the panel's native mode, and the modules the
      # machine actually loads. Without any hardware layer this host still
      # boots -- `base` carries firmware and the common storage drivers -- it
      # simply will not be tuned.
    ];

    module = {
      # REPLACE (1): the real disk, taken from the machine itself.
      #
      #   ls -l /dev/disk/by-id/ | grep -v part
      #
      # This placeholder does not exist, so disko refuses to run rather than
      # partitioning a drive nobody named. That is on purpose: a wrong device
      # letter here erases the wrong disk, and by-id carries the model and
      # serial so a mistake fails instead of destroying.
      #
      # The whole drive is wiped. The laptop arrives with nothing to keep.
      cairn.disk.device = "/dev/disk/by-id/REPLACE-WITH-REAL-DISK-BEFORE-INSTALL";

      # No EF02. This drive boots one machine, that machine has UEFI, and an
      # EF02 partition would make disko pin boot.loader.grub.devices to the
      # install-time path.
      cairn.disk.biosBoot = false;
    };
  };
}
