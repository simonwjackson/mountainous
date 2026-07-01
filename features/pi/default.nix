{
  config,
  lib,
  pkgs,
  mountainousPlatform ? "nixos",
  ...
}: let
  inherit (lib) literalExpression mkEnableOption mkOption optional types;
  cfg = config.mountainous.features.pi;
in {
  imports =
    optional (mountainousPlatform == "nixos") ./nixos.nix
    ++ optional (mountainousPlatform == "droid") ./droid.nix;

  options.mountainous.features.pi = {
    enable = mkEnableOption "pi terminal coding agent (lukasl-dev/pi.nix)";

    rules = mkOption {
      type = types.nullOr types.lines;
      default = null;
      description = ''
        Extra instructions appended to pi's system prompt via
        `--append-system-prompt` on every invocation.
      '';
      example = ''
        - Be concise.
        - Prefer existing project terminology.
      '';
    };

    runtimePackages = mkOption {
      type = types.listOf types.package;
      default = [pkgs.python3 pkgs.ripgrep pkgs.fd pkgs.gnugrep];
      defaultText = literalExpression "[ pkgs.python3 pkgs.ripgrep pkgs.fd pkgs.gnugrep ]";
      description = ''
        Packages prepended to PATH for pi and every tool/skill it spawns.
        Defaults to the interpreters and search tools skills rely on
        (python, ripgrep, fd, grep).
      '';
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Extra raw CLI arguments to always append when launching pi.";
      example = literalExpression ''[ "--provider" "openai" "--model" "gpt-5" ]'';
    };

    environment = mkOption {
      type = types.nullOr (types.attrsOf types.path);
      default = null;
      description = ''
        Map of environment variable names to files whose contents are exported
        as that variable before pi runs. Intended for agenix-managed API keys.
      '';
      example = literalExpression ''
        {
          GROQ_API_KEY = config.age.secrets.groq-api-key.path;
        }
      '';
    };
  };
}
