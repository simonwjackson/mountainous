# Intel Gemini Lake desktop mini PC (Shenzhen CYX Technology Co., Ltd.).
#
# A fixed desktop install targeting the internal 64 GB Samsung eMMC 5.1 drive.
#
# Hardware profile: docs/research/tate-hardware.md
{
  nixos.hosts.tate = {
    system = "x86_64-linux";
    layers = [
      "base"
      "desktop"
      "disk"
      "gemini-lake"
    ];

    module = {
      mountainous.disk.device = "/dev/disk/by-id/mmc-CGND3R_0x96f945e3";
      # Include a 1M EF02 BIOS boot partition alongside the 1G ESP so
      # GRUB can boot under both legacy CSM and UEFI modes.
      mountainous.disk.biosBoot = true;
    };
  };
}
