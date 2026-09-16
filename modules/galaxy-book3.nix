# Samsung Galaxy Book3 Pro 360, model NP960QFG-KA1US.
#
# Derived from the hardware profile captured on the old `asana` host, at
# mountainous commit 1bc75edb, nix/systems/x86_64-linux/asana/HARDWARE.md.
# That machine worked, so this file restates only what it proved was needed.
#
# Relevant identity from that scan:
#   CPU    Intel Core i7-1360P, Raptor Lake-P
#   GPU    Intel Iris Xe, 0000:00:02.0, 0x8086:0xa7a0, driver i915, card1
#   Panel  eDP-1, 2880x1800 OLED, intel_backlight, range 0-400
#   Audio  Intel Alder Lake-P HDA 0000:00:1f.3, Realtek ALC298, sof-hda-dsp
#   WiFi   Intel AX211 Wi-Fi 6E, 0000:00:14.3, driver iwlmvm
#   Touch  Goodix GXTP7936 touchscreen, Imagis IMG4100 touchpad, Wacom EMR pen
{
  nixos.modules.galaxy-book3 =
    { pkgs, ... }:
    {
      # THE reason niri could not open /dev/dri/card1.
      #
      # Iris Xe does not initialise without its blobs, and the scan recorded
      # exactly which ones the working machine loaded:
      #   DMC  i915/adlp_dmc.bin     v2.20
      #   GuC  i915/adlp_guc_70.bin  v70.36.0
      #   HuC  i915/tgl_huc.bin      v7.9.3
      # The same package also carries iwlwifi and SOF audio firmware, so this
      # one line fixes graphics, wifi and sound together.
      hardware.enableRedistributableFirmware = true;
      hardware.cpu.intel.updateMicrocode = true;

      hardware.graphics = {
        enable = true;
        enable32Bit = true;
        extraPackages = with pkgs; [
          intel-media-driver
          vpl-gpu-rt
        ];
      };

      # Kernel parameters carried over from the working asana config.
      # fastboot skips a mode reset the panel does not need, psr=2 and fbc
      # matter for battery on an OLED panel, and the video= line pins the
      # native mode so the console is not stuck at a fallback resolution.
      boot.kernelParams = [
        "i915.fastboot=1"
        "i915.enable_fbc=1"
        "i915.enable_psr=2"
        "video=eDP-1:2880x1800@60"
      ];

      boot.initrd.kernelModules = [ "i915" ]; # early KMS, no ugly mode flip
      boot.kernelModules = [
        "snd_sof_pci_intel_tgl"
        "iwlmvm"
        "btusb"
        "hid_multitouch"
        "intel_ishtp_hid"
      ];

      # 2-in-1 convertible: accelerometer for screen rotation.
      hardware.sensor.iio.enable = true;
      hardware.bluetooth.enable = true;

      services.thermald.enable = true;
      services.acpid.enable = true;
      services.fwupd.enable = true;
      services.hardware.bolt.enable = true; # Thunderbolt 4

      environment.systemPackages = with pkgs; [
        brightnessctl
        pciutils
      ];
    };
}
