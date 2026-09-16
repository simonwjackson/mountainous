# The USB stick.
#
# ridge is a real, writable NixOS install that happens to sit on removable
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
  nixos.hosts.ridge = {
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
      cairn.disk.device = "/dev/sdi";

      # A stick should boot machines with no UEFI at all.
      cairn.disk.biosBoot = true;
    };
  };
}
