# The USB stick.
#
# hiyori is a real, writable NixOS install that happens to sit on removable
# media. You boot it, SSH in, `nixos-rebuild switch`, and the change is still
# there after a reboot. The host machine's internal disk is never touched.
#
# It carries the galaxy-book3 layer because that is the machine it is used on.
# This stick can boot elsewhere, but its graphics and input are tuned for the
# Samsung hardware.
#
# Everything above the disk is shared with summit. If the two ever disagree
# about the desktop, the difference is a bug in a layer, not in this file.
{
  # A USB stick: it sends builds and never builds itself (see module).
  fleet.hostKeys.hiyori = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN6PZlpH4t+PXDhdXg5JNhbnJ9tdNmcb0U7AnbKVLF47";

  nixos.hosts.hiyori = {
    system = "x86_64-linux";
    layers = [
      "desktop"
      "disk"
      "portable"
      "galaxy-book3"
    ];

    module = {
      # /dev/sdi is where the stick appears on the workstation that builds it.
      # The installed system never reads this; it finds its filesystems
      # through /dev/disk/by-partlabel/.
      mountainous.disk.device = "/dev/sdi";
      # Installed before the disk name defaulted to the host name. Its
      # partition labels say "main"; a new name would not find them.
      mountainous.disk.name = "main";

      # A stick should boot machines with no UEFI at all.
      mountainous.disk.biosBoot = true;

      # A stick lives in a pocket, so it is the host most likely to be lost.
      # LUKS2 with a passphrase typed at boot is the only option that fits: it
      # moves between machines, so it cannot be sealed to one machine's TPM,
      # and a stick that unlocks itself unlocks for whoever finds it.
      #
      # The cost is that hiyori alone does not satisfy "rejoins the tailnet
      # unattended" -- someone has to type the passphrase. That is the right
      # thing to give up here. A fixed machine keeps it, via TPM2.
      mountainous.disk.encrypt = true;

      # Builds would wear the stick and fill its RAM: every build goes to the
      # fleet's builders. With none reachable, a build fails; cached paths
      # still download.
      nix.settings.max-jobs = 0;
    };
  };
}
