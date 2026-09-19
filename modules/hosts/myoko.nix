# Host myoko: ASUS Zenbook A16 UX3607OA on its internal NVMe disk.
#
# The disk is not managed by the shared whole-disk layer. Qualcomm platform
# firmware occupies partitions 1 to 11, and the factory ESP is partition 12.
# The guarded installer reclaims only the Windows partitions after those.
{
  nixos.hosts.myoko = {
    system = "aarch64-linux";
    layers = [
      "base"
      "desktop"
      "glymur"
      "myoko-disk"
    ];

    module = {
      lib,
      pkgs,
      ...
    }: let
      # This file comes from this laptop's backed-up Windows driver store.
      # Public A16 board containers differ from it. Keep the private binary
      # outside Git and require its exact content on the native builder.
      wifiBoard = pkgs.requireFile {
        name = "bdwlan_qcc2072_1p0_ncm820A.elf";
        sha256 = "960e9e93da708f5e1086ce15d82d3e44d846ec9441eac40e1725467d357965d8";
        message = ''
          Import Myoko's factory QCC2072 board file on the build machine:
            nix-store --add-fixed sha256 /path/to/bdwlan_qcc2072_1p0_ncm820A.elf
          See docs/research/myoko-post-boot-hardware.md for the source and hash.
        '';
      };
    in {
      nixpkgs.config.allowUnfreePredicate = pkg:
        lib.getName pkg == "bdwlan_qcc2072_1p0_ncm820A.elf";

      # ath12k tries board.bin after both board-2.bin key lookups fail.
      # This scopes the fallback to Myoko and leaves upstream board-2.bin
      # and its regulatory data unchanged. No driver reload runs on activation.
      hardware.firmware = [
        (pkgs.runCommand "myoko-qcc2072-board" {
            # Keep this 125288-byte file readable for the installed hash check.
            passthru.compressFirmware = false;
          } ''
            install -Dm644 ${wifiBoard} \
              "$out/lib/firmware/ath12k/QCC2072/hw1.0/board.bin"
            bash ${../../scripts/test-myoko-wifi-firmware} "$out/lib/firmware"
          '')
      ];

      # Match the display sequence that survived the probe. Alias loading can
      # otherwise race the three drivers during udev coldplug. An explicit
      # modprobe still works for a blacklisted module.
      boot.blacklistedKernelModules = [
        "gpucc-glymur"
        "gxclkctl-kaanapali"
        "msm"
      ];

      # Preserve the GPU-to-GMU dependency until the ordered display service
      # runs during stage 2.
      boot.kernelParams = ["deferred_probe_timeout=300"];

      systemd.services.myoko-display-modules = {
        description = "Load the myoko display dependency chain in order";
        wantedBy = ["multi-user.target"];
        requiredBy = ["greetd.service"];
        before = ["greetd.service"];
        path = [pkgs.kmod];
        script = ''
          set -eu

          for module in gpucc_glymur gxclkctl_kaanapali msm; do
            if [ -d "/sys/module/$module" ]; then
              echo "$module loaded before the ordered display service" >&2
              exit 1
            fi
          done

          modprobe -v gpucc-glymur
          modprobe -v gxclkctl-kaanapali
          modprobe -v msm
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };

      # The first installation intentionally exposes only the services that
      # configure their own access controls. Add a host firewall separately
      # after its policy has been chosen and tested.
      networking.firewall.enable = false;
    };
  };
}
