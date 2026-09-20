{
  inputs,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.dictation-backend = {
    enable = mkEnableOption "local speech-to-text backend";

    modelFile = mkOption {
      type = types.path;
      default = inputs.whisper-large-v3-turbo-model;
      defaultText = lib.literalExpression "inputs.whisper-large-v3-turbo-model";
      description = "Whisper GGML model file.";
    };

    port = mkOption {
      type = types.port;
      default = 8178;
      description = "Local TCP port for whisper-server.";
    };

    language = mkOption {
      type = types.str;
      default = "en";
      description = "Whisper language code.";
    };

    audioContext = mkOption {
      type = types.nullOr types.ints.positive;
      default = null;
      description = "Fixed whisper audio context size, or null to use the full context.";
    };

    proxy = {
      enable = mkEnableOption "expose the dictation backend through tsnet-proxy";

      hostname = mkOption {
        type = types.str;
        default = "dictate";
        description = "Tailscale hostname for the dictation backend.";
      };
    };
  };
}
