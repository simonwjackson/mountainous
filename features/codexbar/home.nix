{
  osConfig,
  lib,
  pkgs,
  ...
}: let
  cfg = osConfig.mountainous.features.codexbar;

  deps = with pkgs; [curl jq coreutils gawk oci-cli];

  mkScript = name: file:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = deps;
      excludeShellChecks = ["SC2086"];
      text = builtins.readFile file;
    };

  codexbar-claude = mkScript "codexbar-claude" ./codexbar-claude.sh;
  codexbar-claude-detail = mkScript "codexbar-claude-detail" ./codexbar-claude-detail.sh;
  codexbar-codex = mkScript "codexbar-codex" ./codexbar-codex.sh;
  codexbar-codex-detail = mkScript "codexbar-codex-detail" ./codexbar-codex-detail.sh;
  codexbar-oci = mkScript "codexbar-oci" ./codexbar-oci.sh;
  codexbar-oci-detail = mkScript "codexbar-oci-detail" ./codexbar-oci-detail.sh;
in {
  config = lib.mkIf cfg.enable {
    home.packages = [
      codexbar-claude
      codexbar-claude-detail
      codexbar-codex
      codexbar-codex-detail
      codexbar-oci
      codexbar-oci-detail
    ];
  };
}
