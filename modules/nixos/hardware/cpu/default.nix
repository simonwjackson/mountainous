{
  system,
  lib,
  inputs,
  pkgs,
  config,
  ...
}: let
  inherit (lib) mkOption types;

  cfg = config.mountainous.hardware.cpu;
in {
  options.mountainous.hardware.cpu = {
    type = mkOption {
      type = types.enum ["amd" "intel" "arm"];
      description = "The manufacturer of the CPU.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.type == "intel") {
      hardware.cpu.intel.updateMicrocode = true;
      # boot.kernelModules = (config.boot.kernelModules or []) ++ ["kvm-intel"];
    })
  ];
}
