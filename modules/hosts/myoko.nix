# Samsung Galaxy Book3 Pro 360 NP960QFG-KA1US, installed on its internal NVMe.
# The removable Hiyori USB is a separate host and must not be partitioned here.
{
  nixos.hosts.myoko = {
    system = "x86_64-linux";
    layers = [
      "base"
      "desktop"
      "disk"
      "galaxy-book3"
    ];

    module = { pkgs, ... }: {
      # Track the newest kernel in the locked nixpkgs revision on Myoko.
      # Keep Hiyori's recovery USB on the default kernel. The OV02C10
      # 26 MHz camera patches were for 6.18 and need a separate port to
      # this kernel; do not apply the old ABI patch to a new kernel.
      boot.kernelPackages = pkgs.linuxPackages_latest;

      # Verified on the Samsung: WDSN740-SDDPNQD-1T00-1004,
      # serial 22501B805583, 1024209543168 bytes, /dev/nvme0n1.
      mountainous.disk.device = "/dev/disk/by-id/nvme-WDSN740-SDDPNQD-1T00-1004_22501B805583";
      # Hiyori may still be plugged in. Keep partlabels and mapper distinct.
      mountainous.disk.name = "myoko";

      # Like Hiyori: passphrase at every boot; only the root is encrypted.
      mountainous.disk.encrypt = true;
    };
  };
}
