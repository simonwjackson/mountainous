# The USB stick.
#
# hiyori is a real, writable NixOS install that happens to sit on removable
# media. You boot it, SSH in, `nixos-rebuild switch`, and the change is still
# there after a reboot. The host machine's internal disk is never touched.
#
# It carries the galaxy-book3 layer because that is the machine it is used on.
# That layer pins a panel mode -- video=eDP-1:2880x1800@60 -- so this stick is
# portable in the sense that it boots elsewhere, not in the sense that it is
# tuned for elsewhere.
#
# Everything above the disk is shared with summit. If the two ever disagree
# about the desktop, the difference is a bug in a layer, not in this file.
{
  nixos.hosts.hiyori = {
    system = "x86_64-linux";
    layers = [
      "base"
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
    };
  };
}
