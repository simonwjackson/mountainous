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
    let
      # The SOF card's UCM profile, without its three HDMI/DisplayPort outputs.
      #
      # Those outputs are the only way the laptop's HDMI port and a monitor on
      # USB-C play sound, and they are never wanted. They also break jack
      # detection. UCM puts the speaker and the headphone jack in two profiles,
      # because they share one PCM. PipeWire calls a profile available while
      # any of its outputs is, so with a monitor attached the headphone profile
      # looked available with nothing in the jack, WirePlumber chose it, and the
      # speakers went silent. Without HDMI, each profile is available exactly
      # when its jack or speaker is, and WirePlumber switches between them when
      # the jack changes.
      #
      # Only PipeWire and WirePlumber read this copy, through ALSA_CONFIG_UCM2.
      # The video signal to monitors does not change.
      ucmWithoutHdmi = pkgs.runCommand "alsa-ucm2-sof-hda-dsp-no-hdmi" { } ''
        cp -r ${pkgs.alsa-ucm-conf}/share/alsa/ucm2 $out
        chmod -R u+w $out
        hifi=$out/Intel/sof-hda-dsp/HiFi.conf
        line='Include.hdmi.File "/Intel/sof-hda-dsp/Hdmi.conf"'
        # Fail the build if alsa-ucm-conf moved the HDMI include.
        grep -qxF "$line" "$hifi"
        grep -vxF "$line" "$hifi" > hifi.conf
        cat hifi.conf > "$hifi"
        ! grep -q Hdmi "$hifi"
      '';
    in
    {
      systemd.user.services.pipewire.environment.ALSA_CONFIG_UCM2 = "${ucmWithoutHdmi}";
      systemd.user.services.wireplumber.environment.ALSA_CONFIG_UCM2 = "${ucmWithoutHdmi}";

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

      hardware.graphics = {
        enable = true;
        enable32Bit = true;
        extraPackages = with pkgs; [
          intel-media-driver
          vpl-gpu-rt
        ];
      };

      # Keep the panel power-saving options from the earlier configuration.
      # Kernel 6.18.52 ignores i915.fastboot and rejects the forced 60 Hz
      # video mode on this panel. Let the panel report its supported modes.
      boot.kernelParams = [
        "i915.enable_fbc=1"
        "i915.enable_psr=2"
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
