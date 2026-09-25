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

    module = {
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
