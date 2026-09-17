# Host myoko: primary laptop on its internal disk (aarch64).
# Evaluates and builds now; installs once hardware arrives.
# See docs/decisions/myoko.md for layering choices and placeholder guards.
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
      mountainous.disk.device = "/dev/disk/by-id/REPLACE-WITH-REAL-DISK-BEFORE-INSTALL";

      # No EF02. This drive boots one machine, that machine has UEFI, and an
      # EF02 partition would make disko pin boot.loader.grub.devices to the
      # install-time path.
      mountainous.disk.biosBoot = false;
    };
  };
}
