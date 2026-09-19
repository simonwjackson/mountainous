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
}: {
  flake.nixosConfigurations.myoko-probe = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = {inherit inputs;};
    modules = [
      config.nixos.modules.glymur
      (
        {
          modulesPath,
          pkgs,
          ...
        }: {
          imports = ["${modulesPath}/installer/netboot/netboot-minimal.nix"];

          nixpkgs.hostPlatform = "aarch64-linux";
          system.stateVersion = "26.11";
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
          users.users.root.openssh.authorizedKeys.keys = [config.mountainous.sshKey];

          networking.wireless.enable = lib.mkForce false;
          networking.networkmanager.enable = true;

          # Keep the display dependency chain from loading through OF aliases
          # before the USB log is mounted. The logging service loads each
          # matching module by name after its synchronous follower is active.
          # A modprobe blacklist blocks aliases but permits an explicit load.
          boot.blacklistedKernelModules = [
            "gpucc-glymur"
            "gxclkctl-kaanapali"
            "msm"
          ];
          boot.kernelParams = [
            "drm.debug=0x1ff"
            "log_buf_len=8M"
          ];

          # The point of mDNS here is that nobody has to read an address off a
          # screen and type it somewhere else. Plug in wired ethernet and the
          # machine is `myoko-probe.local` from the workstation, which is
          # enough to drive the whole bring-up over SSH.
          services.avahi = {
            enable = true;
            nssmdns4 = true;
            publish = {
              enable = true;
              addresses = true;
              workstation = true;
            };
          };

          # ZFS does not build against a 7.3 release candidate, and the
          # installer profile would otherwise drag it in. Nothing this image
          # reads is on a ZFS pool.
          boot.supportedFilesystems.zfs = lib.mkForce false;

          # netboot-base sets hardware.enableAllHardware, which asks the initrd
          # for every storage driver NixOS knows: 3ware RAID, Adaptec SAS, PCMCIA
          # SCSI. The trimmed kernel does not build them, and a requested module
          # that does not exist fails the build outright:
          #
          #   root module: 3w-9xxx
          #   modprobe: FATAL: Module 3w-9xxx not found
          #
          # This image boots one known laptop, so it asks for that laptop's
          # hardware instead of the world's.
          hardware.enableAllHardware = lib.mkForce false;

          # Same reasoning one level down: nixpkgs' default initrd list is
          # written for x86 desktops and asks for ata_piix, ehci_pci and
          # friends. None of them exist in a trimmed arm64 kernel.
          boot.initrd.includeDefaultModules = false;
          boot.initrd.systemd.tpm2.enable = false;
          systemd.tpm2.enable = false;
          boot.swraid.enable = lib.mkForce false;

          # This disposable image is reachable only on the local wired link.
          # The trimmed kernel has no nftables support, and a failed firewall
          # only marks an otherwise useful probe boot as degraded.
          networking.firewall.enable = false;

          boot.initrd.availableKernelModules = [
            "nvme"
            "xhci_pci"
            "xhci_hcd"
            "usbhid"
            "usb_storage"
            "sd_mod"
            "vfat"
            "nls_cp437"
            "nls_iso8859_1"
            "hid_generic"
          ];

          environment.systemPackages = with pkgs; [
            btrfs-progs
            cryptsetup
            dosfstools
            gptfdisk
            pciutils
            usbutils
            util-linux
          ];

          # The previous display probe could reset before SSH or the panel
          # worked. This service makes the firmware USB an independent flight
          # recorder. The mount uses synchronous writes, then dmesg follows the
          # kernel before the GPU clock controllers and MSM load explicitly.
          # If display bring-up fails, recovery can read the completed lines.
          systemd.services.myoko-probe-display-log = {
            description = "Capture myoko display bring-up to the firmware USB";
            wantedBy = ["multi-user.target"];
            wants = ["dev-disk-by\\x2dlabel-MYOKO\\x2dFW.device"];
            after = ["dev-disk-by\\x2dlabel-MYOKO\\x2dFW.device"];
            path = with pkgs; [
              coreutils
              kmod
              util-linux
            ];
            script = ''
              set -eu

              device=/dev/disk/by-label/MYOKO-FW
              mountpoint=/run/myoko-probe-usb
              boot_id=$(cat /proc/sys/kernel/random/boot_id)
              log="$mountpoint/myoko-display-$boot_id.log"

              mkdir -p "$mountpoint"
              mount -o rw,sync "$device" "$mountpoint"
              trap 'umount "$mountpoint" 2>/dev/null || true' EXIT

              {
                echo "myoko display probe $boot_id"
                echo "cmdline: $(cat /proc/cmdline)"
                echo "kernel: $(uname -a)"
                echo "--- dmesg before msm ---"
                dmesg --color=never
                echo "--- following dmesg; loading display modules ---"
              } > "$log"
              sync -f "$log"

              for module in gpucc_glymur gxclkctl_kaanapali msm; do
                if [ -d "/sys/module/$module" ]; then
                  echo "SAFETY FAILURE: $module loaded before the USB logger" >> "$log"
                  sync -f "$log"
                  exit 1
                fi
              done

              stdbuf -oL dmesg --follow-new --color=never >> "$log" &
              follower=$!
              trap 'kill "$follower" 2>/dev/null || true; sync -f "$log" 2>/dev/null || true; umount "$mountpoint" 2>/dev/null || true' EXIT

              echo "--- modprobe gpucc-glymur ---" >> "$log"
              sync -f "$log"
              modprobe -v gpucc-glymur >> "$log" 2>&1
              echo "--- modprobe gxclkctl-kaanapali ---" >> "$log"
              sync -f "$log"
              modprobe -v gxclkctl-kaanapali >> "$log" 2>&1
              echo "--- modprobe msm ---" >> "$log"
              sync -f "$log"
              modprobe -v msm >> "$log" 2>&1
              echo "--- display modules loaded; logger remains active ---" >> "$log"
              sync -f "$log"

              wait "$follower"
            '';
            serviceConfig = {
              Type = "simple";
              Restart = "no";
            };
          };

          services.getty.helpLine = lib.mkAfter ''

            myoko probe. Nothing has been written to this laptop.

            This console is the fallback. With a wired connection the machine
            answers to myoko-probe.local and the work happens over SSH.

              address: \4        (blank means no network yet)

            The question this image exists to answer:

              lsblk -o NAME,SIZE,PARTLABEL,PARTTYPENAME /dev/nvme0n1

            Also worth reading before anything is installed:

              cat /sys/power/mem_sleep          only s2idle should be listed
              dmesg | grep -iE 'soccp|remoteproc|adsp|cdsp'
              dmesg | grep -iE 'edp|dp_display|panel'
              ip -4 addr                        if a USB ethernet adapter is in

            Display bring-up is also written synchronously to the firmware USB:

              /myoko-display-<boot-id>.log
          '';
        }
      )
    ];
  };

  perSystem = {system, ...}:
    lib.mkIf (system == "aarch64-linux") {
      packages.myoko-probe = config.flake.nixosConfigurations.myoko-probe.config.system.build.uki;
    };
}
