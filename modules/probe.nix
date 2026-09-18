# A single EFI file that boots myoko before anything is installed on it.
#
# The installer ISO in this tree cannot be used here. It boots through GRUB,
# and nixpkgs' ISO builder has no way to hand the kernel a devicetree. Without
# one this laptop does not come up far enough to print anything.
#
# So the probe is a Unified Kernel Image instead: kernel, initrd, command line
# and the devicetree, all in one PE binary that the firmware loads directly
# from the removable-media path. nixpkgs already wires hardware.deviceTree
# into the UKI's DeviceTree section, so the machine is described from the
# moment the stub hands over.
#
# The whole Nix store rides inside the initrd, netboot style. That keeps the
# USB layout to one FAT32 partition with one file on it, which means the stick
# that carries the extracted firmware can also carry this, and writing it does
# not repartition anything.
#
# Build:  nix build .#myoko-probe
# Write:  cp result/*.efi /mnt/usb/EFI/BOOT/BOOTAA64.EFI
{
  config,
  inputs,
  lib,
  ...
}:
{
  flake.nixosConfigurations.myoko-probe = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit inputs; };
    modules = [
      config.nixos.modules.glymur
      (
        { modulesPath, pkgs, ... }:
        {
          imports = [ "${modulesPath}/installer/netboot/netboot-minimal.nix" ];

          nixpkgs.hostPlatform = "aarch64-linux";
          networking.hostName = "myoko-probe";

          # The store lives in the initrd, so the UKI must carry that one
          # rather than the ordinary stage-1 image.
          boot.uki.settings.UKI.Initrd = lib.mkForce "${config.flake.nixosConfigurations.myoko-probe.config.system.build.netbootRamdisk}/initrd";

          # First boot on new hardware is read from the screen, not over the
          # network. Wi-Fi needs a board file this laptop does not have yet,
          # so assume no network at all and make the console enough. The
          # installation-device profile that netboot-minimal pulls in already
          # logs in as `nixos` with passwordless sudo, which is why there is no
          # autologin or password set here.
          services.openssh = {
            enable = true;
            settings = {
              PermitRootLogin = "yes";
              PasswordAuthentication = false;
            };
          };
          users.users.root.openssh.authorizedKeys.keys = [ config.mountainous.sshKey ];

          networking.wireless.enable = lib.mkForce false;
          networking.networkmanager.enable = true;

          # ZFS does not build against a 7.3 release candidate, and the
          # installer profile would otherwise drag it in. Nothing this image
          # reads is on a ZFS pool.
          boot.supportedFilesystems.zfs = lib.mkForce false;

          environment.systemPackages = with pkgs; [
            pciutils
            usbutils
            gptfdisk
            util-linux
          ];

          services.getty.helpLine = lib.mkAfter ''

            myoko probe. Nothing has been written to this laptop.

            The question this image exists to answer:

              lsblk -o NAME,SIZE,PARTLABEL,PARTTYPENAME /dev/nvme0n1

            Also worth reading before anything is installed:

              cat /sys/power/mem_sleep          only s2idle should be listed
              dmesg | grep -iE 'soccp|remoteproc|adsp|cdsp'
              dmesg | grep -iE 'edp|dp_display|panel'
              ip -4 addr                        if a USB ethernet adapter is in
          '';
        }
      )
    ];
  };

  perSystem =
    { system, ... }:
    lib.mkIf (system == "aarch64-linux") {
      packages.myoko-probe = config.flake.nixosConfigurations.myoko-probe.config.system.build.uki;
    };
}
