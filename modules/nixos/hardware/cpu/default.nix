{
  system,
  lib,
  inputs,
  pkgs,
  config,
  ...
}: let
  inherit (lib) types mkEnableOption mkOption;

  cfg = config.mountainous.hardware.cpu;
in {
  options.mountainous.hardware.cpu = {
    enable = mkEnableOption "Whether to enable cpu configurations";

    type = mkOption {
      type = types.enum ["amd" "intel" "arm"];
      description = "The manufacturer of the CPU.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf (cfg.type == "intel") {
        hardware.cpu.intel.updateMicrocode = true;
        boot.kernelModules = ["kvm-intel"];
      })

      (lib.mkIf (cfg.type == "amd") {
        boot.initrd.kernelModules = [
          "amdgpu"
        ];
        services.udev.extraRules = ''
          KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"
        '';
        boot.kernelParams = ["amd_pstate=passive" "amd_pstate.shared_mem=1"]; # Add this line
        boot.kernelModules = [
          "kvm-amd"
          # TODO: move this to ryzen config file
          "ryzen_smu"
        ];
        hardware.cpu.amd.updateMicrocode = true;

        environment.systemPackages = with pkgs; [
          ryzenadj
        ];
      })
    ]
  );
}
