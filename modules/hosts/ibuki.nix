# Intel NUC8i3BEK, targeting its internal Kingston M.2 SATA SSD.
# Hardware evidence: docs/research/ibuki-hardware.md.
# Hiyori is a separate recovery USB and must not be partitioned here.
{ inputs, ... }:
{
  nixos.hosts.ibuki = {
    system = "x86_64-linux";
    # modules/korri.nix: the Korri product needs Korri's own nixpkgs.
    nixpkgs = inputs.korri.inputs.nixpkgs;
    layers = [
      "base"
      "disk"
      "server"
      "korri"
    ];

    module = { pkgs, ... }: {
      mountainous.disk = {
        device = "/dev/disk/by-id/ata-KINGSTON_SUV500M8240G_50026B7683B6CE9D";
        # The SSD and recovery USB currently share disk-main-* labels.
        # A distinct namespace keeps the installed system off the USB.
        name = "ibuki";
        encrypt = false;
        biosBoot = false;
      };

      # Storage and network drivers probe automatically. The shared base
      # already supplies AHCI, sd_mod, USB support, and firmware.
      hardware.cpu.intel.updateMicrocode = true;
      services.thermald.enable = true;

      # GPU libraries do not require a desktop. Mesa supplies Iris OpenGL
      # and ANV Vulkan, including the 32-bit stack used by Wine and games.
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
        extraPackages = [ pkgs.intel-media-driver ];
        extraPackages32 = [ pkgs.pkgsi686Linux.intel-media-driver ];
      };
      boot.initrd.kernelModules = [ "i915" ];

      # Let the later Jellyfin client use VA-API without root or a local seat.
      users.users.simon.extraGroups = [ "render" ];

      # Korri hardware facts. The i915 GPU is PCI 0000:00:02.0. Its card
      # number follows probe order (card1 behind simpledrm in the profile),
      # so the card is named by PCI path. The LG TV is on DP-1 and prefers
      # 3840x2160 at 60 Hz (docs/research/ibuki-hardware.md).
      services.korriLinuxHost.compositor = {
        backend = "drm";
        localInput.enable = true;
        drmDevice = "/dev/dri/by-path/pci-0000:00:02.0-card";
        renderDevice = "/dev/dri/by-path/pci-0000:00:02.0-render";
        outputName = "DP-1";
        mode = "3840x2160@60Hz";
      };

      environment.systemPackages = with pkgs; [
        libva-utils
        vulkan-tools
        intel-gpu-tools
      ];
    };
  };
}
