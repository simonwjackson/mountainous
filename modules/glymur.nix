# The Snapdragon X2 Elite (Qualcomm "Glymur") layer.
#
# This machine is driven from a devicetree, not from the ACPI tables its UEFI
# hands out for Windows. Nothing here is a preference: without the devicetree
# the kernel does not know what the hardware is. The display patch set matches
# the working report from the owner of the same UX3607OA model.
#
# Kernel floor is 7.3. The board devicetree for the ASUS Zenbook A16 (UX3607OA)
# landed in that release as commit e8fbbca94db7, so linux_testing is the oldest
# tree that can describe this laptop at all.
{
  nixos.modules.glymur = {
    config,
    lib,
    pkgs,
    ...
  }: {
    boot.kernelPackages = pkgs.linuxPackagesFor (
      pkgs.linux_testing.override (old: {
        # nixpkgs answers "m" to every driver question it is not told about,
        # which on arm64 means compiling several thousand modules for
        # hardware this laptop does not have: NFC readers, Tegra boards,
        # PCI sound cards. The base config is `make defconfig`, and upstream
        # put the Glymur options into arm64 defconfig when the SoC landed
        # ("arm64: defconfig: Enable Glymur configs for boot to shell"), so
        # turning the automatic pass off leaves the machine described and
        # drops the tail. Anything the probe cannot boot without is named
        # below rather than left to the default.
        autoModules = false;

        # With the automatic pass off, most of nixpkgs' common config is
        # answering questions that no longer exist: CIFS_XATTR without CIFS,
        # SND_HDA_CODEC_CS8409 without HDA, joystick force-feedback without
        # the joysticks. aarch64 treats an unused answer as a hard error, so
        # a trimmed kernel cannot be configured without this. The cost is
        # that a missing option is now silent too, which is what
        # scripts/check-kernel-config exists to catch.
        ignoreConfigErrors = true;

        structuredExtraConfig = with lib.kernel; {
          # arm64 defconfig builds the CPUCP mailbox as a module. On Glymur
          # it then loads after SCMI has already timed out, and no CPU gets
          # a frequency governor. Reported during the HP EliteBook X G2q
          # bring-up on this SoC.
          QCOM_CPUCP_MBOX = yes;

          # This option has no arm64 defconfig default. Without it, the GPU
          # SMMU waits for a clock provider that does not exist, times out,
          # and MSM DRM cannot bind. Keep the controller and MSM as matching
          # modules so a probe can start logging before either one loads.
          CLK_GLYMUR_GPUCC = module;

          # The UKI is loaded by the firmware as an EFI application, so the
          # stub is not optional here.
          EFI = yes;
          EFI_STUB = yes;

          # Root, boot medium and the store the initrd carries.
          BLK_DEV_NVME = yes;
          DM_CRYPT = module;
          SQUASHFS = yes;
          EXT4_FS = yes;
          VFAT_FS = yes;
          USB_STORAGE = yes;
          USB_XHCI_HCD = yes;
          USB_XHCI_PLATFORM = yes;

          # Kanata needs a virtual input device to emit remapped keys.
          INPUT_UINPUT = module;

          # If msm never lights the panel, the UEFI framebuffer still gives
          # a console to read. That is the difference between a failed boot
          # we can diagnose and one we cannot see.
          DRM = yes;
          DRM_SIMPLEDRM = yes;
          SYSFB_SIMPLEFB = yes;
          FRAMEBUFFER_CONSOLE = yes;

          # The chipset in the USB ethernet adapter is unknown, and the
          # whole autonomous path depends on the link coming up, so carry
          # the common ones rather than guess.
          USB_USBNET = module;
          USB_RTL8152 = module;
          USB_NET_AX8817X = module;
          USB_NET_AX88179_178A = module;
          USB_NET_CDCETHER = module;
          USB_NET_CDC_NCM = module;
          USB_NET_RNDIS_HOST = module;

          # NixOS' iptables backend uses the iptables-nft userspace tools.
          # Without these, firewall.service fails with "Failed to initialize
          # nft: Protocol not supported".
          NF_TABLES = module;
          NF_TABLES_IPV4 = yes;
          NF_TABLES_IPV6 = yes;
          NFT_COMPAT = module;
        };

        kernelPatches =
          (old.kernelPatches or [])
          ++ [
            # Reproduce the complete display patch set from the working
            # UX3607OA report at A16UbuntuBuild commit 3de6f0a. The posted v8
            # PHY series fixes the per-rate programming, but this Samsung
            # panel still fails four-lane HBR2 equalization. The reference
            # forces the DT-supported HBR3 rate and guards the failed-enable
            # disable path that can otherwise reset Glymur silently.
            {
              name = "glymur-edp-phy-split-power-on";
              patch = ./glymur/0001-phy-qcom-edp-split-power-on-sequencing-by-phy-version.patch;
            }
            {
              name = "glymur-edp-phy-v8-power-on";
              patch = ./glymur/0002-phy-qcom-edp-update-v8-power-on-programming-sequence.patch;
            }
            {
              name = "glymur-dp-skip-idle-after-failed-enable";
              patch = ./glymur/0003-drm-msm-dp-skip-push-idle-when-link-never-enabled.patch;
            }
            {
              name = "myoko-edp-force-hbr3";
              patch = ./glymur/0004-drm-msm-dp-force-edp-rate-to-hbr3.patch;
            }
          ];
      })
    );

    # The stock trimmed kernel omits hid-asus. Build only that module instead
    # of recompiling the full kernel, which has twice locked this machine under
    # sustained compiler load. The source and build tree come from the exact
    # running kernel package, so the module keeps matching its kernel.
    boot.extraModulePackages = [
      (config.boot.kernelPackages.callPackage ../nix/myoko-hid-asus.nix {})
      # BlueZ creates Bluetooth Low Energy input devices through /dev/uhid.
      # Build this one matching module instead of rebuilding the trimmed kernel.
      (config.boot.kernelPackages.callPackage ../nix/myoko-uhid.nix {})
      # Bluetooth headset microphones need HFP, and HFP carries its AT command
      # channel over an RFCOMM socket. Without this module the kernel answers
      # socket(STREAM, RFCOMM) with EPROTONOSUPPORT, BlueZ never connects the
      # Hands-Free profile, and PipeWire exposes the headset as output only.
      (config.boot.kernelPackages.callPackage ../nix/myoko-rfcomm.nix {})
    ];

    # Load these modules before the desktop starts. hid_asus maps the vendor
    # keyboard usages. uhid lets BlueZ create Bluetooth LE input devices.
    # rfcomm lets BlueZ and PipeWire open the HFP command channel.
    boot.kernelModules = [
      "hid_asus"
      "rfcomm"
      "uhid"
    ];

    # Keep the firmware closure to the files this platform can request. The
    # full linux-firmware package is 1.9 GiB and would make the probe UKI too
    # large for firmware to load reliably.
    hardware.firmware = [
      (pkgs.runCommand "glymur-upstream-firmware" {} ''
        mkdir -p "$out/lib/firmware/qcom/glymur"
        mkdir -p "$out/lib/firmware/qcom/vpu"
        mkdir -p "$out/lib/firmware/rtl_nic"

        cp -L ${pkgs.linux-firmware}/lib/firmware/qcom/gen80100_aqe.fw "$out/lib/firmware/qcom/"
        cp -L ${pkgs.linux-firmware}/lib/firmware/qcom/gen80100_gmu.bin "$out/lib/firmware/qcom/"
        cp -L ${pkgs.linux-firmware}/lib/firmware/qcom/gen80100_sqe.fw "$out/lib/firmware/qcom/"
        cp -L ${pkgs.linux-firmware}/lib/firmware/qcom/glymur/gen80100_zap.mbn "$out/lib/firmware/qcom/glymur/"
        cp -L ${pkgs.linux-firmware}/lib/firmware/qcom/vpu/vpu36_p4_s7.mbn "$out/lib/firmware/qcom/vpu/"
        cp -L ${pkgs.linux-firmware}/lib/firmware/rtl_nic/rtl8156b-2.fw "$out/lib/firmware/rtl_nic/"
      '')
    ];

    # systemd-boot writes a `devicetree` line into the boot entry, and the
    # UKI carries the same file in a PE section. Either way this name is
    # what selects the machine.
    hardware.deviceTree = {
      enable = true;
      name = "qcom/glymur-asus-zenbook-a16-ux3607oa.dtb";
    };
  };
}
