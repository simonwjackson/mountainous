# Intel Gemini Lake desktop mini PC (Shenzhen CYX Technology Co., Ltd.).
#
# A fixed headless server install targeting the internal 64 GB Samsung eMMC 5.1 drive.
#
# Hardware profile: docs/research/tate-hardware.md
{
  nixos.hosts.tate = {
    system = "x86_64-linux";
    layers = [
      "disk"
      "gemini-lake"
      "server"
      "printing"
    ];

    module = {
      mountainous.disk.device = "/dev/disk/by-id/mmc-CGND3R_0x96f945e3";
      # Installed before the disk name defaulted to the host name. Its
      # partition labels say "main"; a new name would not find them.
      mountainous.disk.name = "main";
      # Include a 1M EF02 BIOS boot partition alongside the 1G ESP so
      # GRUB can boot under both legacy CSM and UEFI modes.
      mountainous.disk.biosBoot = true;

      # A 4-core Celeron on eMMC: never build here. Deploys build elsewhere
      # and copy the result (nixos-rebuild without --build-host tate).
      # Store paths still come from the caches.
      nix.settings.max-jobs = 0;

      # The office Brother HL-L2300D moves its USB cable from zao to here.
      # The serial in the URI identifies that one physical unit, so the queue
      # follows the printer rather than the USB port.
      mountainous.printing = {
        enable = true;
        deviceUri = "usb://Brother/HL-L2300D%20series?serial=U63878A0N138131";
      };
    };
  };
}
