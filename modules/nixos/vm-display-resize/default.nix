{lib, config, pkgs, ...}:
with lib;
{
  options.mountainous.vm-display-resize = {
    enable = mkEnableOption "VM display auto-resizing";
  };

  config = mkIf config.mountainous.vm-display-resize.enable {
    # Enable QEMU Guest Agent
    services.qemuGuest.enable = true;
  
    # VM-specific packages and services
    environment.systemPackages = with pkgs; [
      # Install SPICE agent and utilities
      spice-vdagent   # This enables auto-resize and clipboard sharing
      xorg.xrandr     # Useful for manual resolution changes if needed
    ];
    
    # For better graphics performance (if using VirtIO)
    boot.initrd.kernelModules = [ "virtio_gpu" ];
  
    # Enable X11 auto-resize for SPICE
    services.xserver.videoDrivers = [ "qxl" ]; # Use "virtio" if using VirtIO graphics
  
    # For Wayland-based desktops like Hyprland
    hardware.opengl.enable = true;

    # VM-specific configuration that only applies when building a VM
    virtualisation.vmVariant = {
      # These settings only apply when building with nixos-rebuild build-vm
      virtualisation = {
        memorySize = 4096; # Example: Set VM memory to 4GB
        cores = 4;         # Example: Set VM cores
      
        qemu.options = [
          # Force auto-resize to be enabled
          "-device virtio-gpu-pci"
          "-display gtk,gl=on"
        ];
      };
    };
 
    services.spice-vdagentd.enable = true;
  };
}
