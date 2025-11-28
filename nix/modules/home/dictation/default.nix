{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types mkIf;
  cfg = config.mountainous.dictation;

  # Generate config content
  configContent = lib.concatStringsSep "\n" (
    lib.optional (cfg.remoteHost != null) "DICTATION_REMOTE_HOST=${cfg.remoteHost}"
    ++ lib.optional (cfg.whisperModel != null) "DICTATION_WHISPER_MODEL=${cfg.whisperModel}"
  );
in {
  options.mountainous.dictation = {
    enable = mkEnableOption "dictation with speech-to-text";

    remoteHost = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Remote host for transcription via SSH.
        If null, uses local stt binary.
        The remote host must have whisper-cpp and sox installed.
      '';
      example = "server.local";
    };

    whisperModel = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Path to whisper model on remote host.
        Defaults to ~/.local/share/whisper/models/ggml-tiny.en.bin on remote.
      '';
      example = "~/.local/share/whisper/models/ggml-small.en.bin";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [pkgs.dictation];

    # Write config file if remote mode is configured
    xdg.configFile."dictation/config" = mkIf (cfg.remoteHost != null) {
      text = configContent;
    };
  };
}
