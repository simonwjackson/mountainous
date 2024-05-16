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
        boot.kernelModules = ["kvm-amd"];
        hardware.cpu.amd.updateMicrocode = true;

        environment.systemPackages = with pkgs; [
          ryzenadj
        ];
      })
    ]
  );
}
