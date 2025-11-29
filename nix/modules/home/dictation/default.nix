{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types mkIf;
  cfg = config.mountainous.dictation;

  # Available whisper models (declaratively fetched)
  models = {
    tiny-en = pkgs.fetchurl {
      url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin";
      hash = "sha256-kh5M+Ghv3Zk9zQgaXaW2w2W/3hFi5ysI11rHUomSCx8=";
    };
    base-en = pkgs.fetchurl {
      url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin";
      hash = "sha256-oDd5yG3zMjB19eeWyyzlAp8A7Ihp7uP9+4l6/jbG0AI=";
    };
    small-en = pkgs.fetchurl {
      url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin";
      hash = "sha256-xhONbVjsyDIgl+D5h8MvG+i7ChhTKj+I9zTRu/nEHl0=";
    };
  };

  # Resolve model path (either from models attrset or custom path/derivation)
  modelPath =
    if builtins.isString cfg.whisperModel && builtins.hasAttr cfg.whisperModel models
    then models.${cfg.whisperModel}
    else cfg.whisperModel;

  # Generate config content
  configContent = lib.concatStringsSep "\n" (
    lib.optional (cfg.remoteHost != null) "DICTATION_REMOTE_HOST=${cfg.remoteHost}"
    ++ lib.optional (modelPath != null) "DICTATION_WHISPER_MODEL=${modelPath}"
  );

  hasConfig = cfg.remoteHost != null || modelPath != null;
in {
  options.mountainous.dictation = {
    enable = mkEnableOption "dictation with speech-to-text using whisper";

    remoteHost = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Remote host for transcription via SSH.
        If null, transcription runs locally using whisper-cli.
        The remote host must have Nix installed (uses nix shell for whisper-cpp).
      '';
      example = "server.local";
    };

    whisperModel = mkOption {
      type = types.nullOr (types.either types.str types.path);
      default = "tiny-en";
      description = ''
        Whisper model to use for transcription.

        Can be one of the built-in models:
        - "tiny-en" (39MB, fastest, English only)
        - "base-en" (74MB, fast, English only)
        - "small-en" (244MB, accurate, English only)

        Or a path/derivation to a custom model file.
      '';
      example = lib.literalExpression ''
        # Use built-in model by name
        "small-en"

        # Or fetch a custom model
        pkgs.fetchurl {
          url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin";
          hash = "sha256-...";
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    home.packages = [pkgs.dictation];

    # Write config file with model path
    xdg.configFile."dictation/config" = mkIf hasConfig {
      text = configContent;
    };
  };
}
