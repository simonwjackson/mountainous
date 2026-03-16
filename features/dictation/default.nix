{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types mkIf;
  cfg = config.mountainous.features.dictation;
in {
  options.mountainous.features.dictation = {
    enable = mkEnableOption "speech-to-text dictation via Groq Whisper API";

    apiKeyEnvFile = mkOption {
      type = types.str;
      default = "/run/agenix/groq-env";
      description = ''
        Path to an env file containing GROQ_API_KEY=... (sourced by the script).
      '';
    };

    model = mkOption {
      type = types.str;
      default = "whisper-large-v3-turbo";
      description = ''
        Whisper model to use. Available on Groq:
          whisper-large-v3-turbo (faster)
          whisper-large-v3 (more accurate)
      '';
    };

    language = mkOption {
      type = types.str;
      default = "en";
      description = "Language code for transcription.";
    };
  };

  config = mkIf cfg.enable {
    age.secrets.groq-env = {
      file = ../../secrets/groq-env.age;
      mode = "0440";
      owner = "simonwjackson";
    };

    home-manager.users.simonwjackson.imports = [
      ./home.nix
    ];
  };
}
