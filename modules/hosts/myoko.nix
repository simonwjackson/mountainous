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
      # Felipe Calliari's 2026-09-23 v3 series for Samsung's 26 MHz OV02C10.
      # https://ratatoskr.run/linux-media/2026/09/17632924
      # Apply to Myoko only. Keep Hiyori's USB kernel unchanged as recovery.
      boot.kernelPatches =
        (map (part: {
          name = "ov02c10-26mhz-v3-${toString part}";
          patch = ../galaxy-book3-camera/ov02c10-v3-${toString part}.patch;
        }) [ 1 2 3 4 5 ])
        ++ [
          # v3 targets a newer V4L2 callback ABI; 6.18 has no client_info.
          {
            name = "ov02c10-linux-6.18-get-selection";
            patch = ../galaxy-book3-camera/ov02c10-linux-6.18-get-selection.patch;
          }
        ];

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
