{ config, lib, ... }:

{
  hardware.opengl.enable = true;
  hardware.nvidia.prime.offload.enable = lib.mkForce true;
  services.xserver.videoDrivers = [ "nvidia" ];

  # Optionally, you may need to select the appropriate driver version for your specific GPU.
  hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.production;
}
