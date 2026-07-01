{
  osConfig,
  lib,
  pkgs,
  ...
}: let
  cfg = osConfig.mountainous.features.codexbar;

  deps = with pkgs; [coreutils gawk gnugrep oci-cli];

  mkScript = name: file:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = deps;
      excludeShellChecks = ["SC2086"];
      text = builtins.readFile file;
    };

  codexbar-oci = mkScript "codexbar-oci" ./codexbar-oci.sh;
  codexbar-oci-detail = mkScript "codexbar-oci-detail" ./codexbar-oci-detail.sh;
in {
  config = lib.mkIf cfg.enable {
    home.packages = [
      codexbar-oci
      codexbar-oci-detail
    ];
  };
}
