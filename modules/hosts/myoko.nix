# Samsung Galaxy Book3 Pro 360 NP960QFG-KA1US, installed on its internal NVMe.
# The removable Hiyori USB is a separate host and must not be partitioned here.
{
  nixos.hosts.myoko = {
    system = "x86_64-linux";
    layers = [
      "desktop"
      "disk"
      "galaxy-book3"
      "session-restore"
    ];

    module = { pkgs, ... }: {
      # Track the newest kernel in the locked nixpkgs revision on Myoko.
      # Keep Hiyori's recovery USB on the default kernel.
      boot.kernelPackages = pkgs.linuxPackages_latest;

      # Felipe Calliari's 2026-09-23 v3 series for Samsung's 26 MHz OV02C10.
      # https://ratatoskr.run/linux-media/2026/09/17632924
      # Myoko only. Hiyori's recovery USB keeps its unpatched kernel.
      boot.kernelPatches =
        (map (part: {
          name = "ov02c10-26mhz-v3-${toString part}";
          patch = ../galaxy-book3-camera/ov02c10-v3-${toString part}.patch;
        }) [ 1 2 3 4 5 ])
        ++ [
          # The v3 series was written against 7.3-rc1, where get_selection
          # takes a client_info argument. The locked kernel does not have it.
          {
            name = "ov02c10-get-selection-no-client-info";
            patch = ../galaxy-book3-camera/ov02c10-get-selection-no-client-info.patch;
          }
        ];

      # Verified on the Samsung: WDSN740-SDDPNQD-1T00-1004,
      # serial 22501B805583, 1024209543168 bytes, /dev/nvme0n1.
      mountainous.disk.device = "/dev/disk/by-id/nvme-WDSN740-SDDPNQD-1T00-1004_22501B805583";
      # Like Hiyori: passphrase at every boot; only the root is encrypted.
      mountainous.disk.encrypt = true;

      # Send downloaded meeting transcripts (.vtt) to the store on Zao.
      mountainous.features.meetings-upload.enable = true;

      # The Android tablet as a second screen below the panel, over Tailscale.
      mountainous.features.sunshine.enable = true;

      # OBS's program output as a camera in Chromium video calls.
      mountainous.features.obs.enable = true;

      # The operator's daily machine shows the servers' storage health.
      mountainous.features.storage-health.enable = true;
    };
  };
}
