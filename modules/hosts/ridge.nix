# One x86 machine.
#
# Hardware is not described here. `nixos-facter` writes ridge.facter.json on
# the machine itself, and the nixpkgs module reads it. There is no
# hardware-configuration.nix to hand-maintain.
#
# Generate the report once, as root, on the target:
#   nix-shell -p nixos-facter --run nixos-facter > ridge.facter.json
{
  nixos.hosts.ridge = {
    system = "x86_64-linux";
    layers = [
      "base"
      "desktop"
    ];

    module = {
      hardware.facter.reportPath = ./ridge.facter.json;

      fileSystems."/" = {
        device = "/dev/disk/by-label/nixos";
        fsType = "ext4";
      };

      fileSystems."/boot" = {
        device = "/dev/disk/by-label/BOOT";
        fsType = "vfat";
      };
    };
  };
}
