# Intel Gemini Lake desktop mini PC (Shenzhen CYX Technology Co., Ltd.).
#
# Hardware profile collected live via Hiyori portable USB boot:
#   CPU      Intel Celeron J4105 @ 1.50 GHz (4C/4T, Gemini Lake)
#   GPU      Intel UHD Graphics 600, 0000:00:02.0, 0x8086:0x3185, driver i915
#   eMMC     Samsung CGND3R 64 GB eMMC 5.1 (/dev/mmcblk1), controller 0000:00:1e.0 0x8086:0x31d0
#   Ethernet Realtek RTL8111/8168 Gigabit Ethernet, 0000:05:00.0, 0x10ec:0x8168, driver r8169
#   WiFi     Intel Dual Band Wireless-AC 3165, 0000:06:00.0, 0x8086:0x3165, driver iwlwifi
#   BT       Intel Bluetooth USB 1-4, 0x8087:0x0a2a, driver btusb
#   Audio    Intel HDA PCH 0000:00:0e.0 0x8086:0x3198, Realtek ALC269VC + Intel HDMI
#   Firmware AMI Aptio V 5.13 (2019-09-30), dual UEFI + Legacy CSM
{
  nixos.modules.gemini-lake =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      hardware.enableRedistributableFirmware = true;
      hardware.cpu.intel.updateMicrocode = true;

      # The internal eMMC storage sits behind an SDHCI controller (0000:00:1e.0 [8086:31d0]).
      # The baseline initrd in base.nix omits sdhci_pci and mmc_block, without which
      # stage 1 cannot find /dev/mmcblk1.
      boot.initrd.availableKernelModules = [
        "sdhci_pci"
        "mmc_block"
        "ahci"
        "r8169"
      ];

      # Early KMS prevents mode flickering on boot.
      boot.initrd.kernelModules = [ "i915" ];

      boot.kernelModules = [
        "iwlwifi"
        "btusb"
        "r8169"
        "snd_hda_intel"
        "rtsx_usb"
      ];

      hardware.graphics = {
        enable = true;
        enable32Bit = lib.mkDefault false;
        extraPackages = with pkgs; [
          intel-media-driver
          intel-vaapi-driver
          libvdpau-va-gl
        ];
      };

      hardware.bluetooth.enable = lib.mkDefault true;
      services.acpid.enable = true;
      services.thermald.enable = true;

      # The AMI Aptio V firmware supports both UEFI and legacy BIOS boot.
      # Configuring GRUB with removable EFI support allows booting whether the
      # firmware is configured for native UEFI or legacy CSM.
      #
      # No `grub.device` is set here. disko already appends the install disk to
      # `grub.devices` whenever the layout carries an EF02 partition (see
      # modules/disk.nix), so naming it again only duplicates the entry.
      boot.loader.systemd-boot.enable = lib.mkForce false;
      boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
      boot.loader.grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
      };

      environment.systemPackages = with pkgs; [
        pciutils
        usbutils
        ethtool
      ];
    };
}
