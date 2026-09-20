# Hold-to-talk dictation for the Quickshell desktop.
#
# Quickshell owns the take state machine. Hyprland reports Right Alt press,
# release, and cancel events through IPC. The helper owns one backend request
# and one insertion, but it holds no state between takes.
{
  nixos.modules.desktop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.mountainous.features.dictation;
      inherit (lib)
        mkEnableOption
        mkIf
        mkOption
        types
        ;

      dictation-submit = pkgs.writeShellApplication {
        name = "dictation-submit";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.curl
          pkgs.jq
          pkgs.systemd
          pkgs.wl-clipboard
          pkgs.wtype
        ];
        text = builtins.readFile ./dictation-submit.sh;
      };
    in
    {
      options.mountainous.features.dictation = {
        enable = mkEnableOption "hold-to-talk dictation";

        backendOrder = mkOption {
          type = types.listOf (
            types.enum [
              "zao"
              "groq"
            ]
          );
          default = [
            "zao"
            "groq"
          ];
          description = "Backends to try, in order.";
        };

        zaoUrl = mkOption {
          type = types.str;
          default = "https://dictate.hummingbird-lake.ts.net/v1/audio/transcriptions";
          description = "Zao's OpenAI-compatible transcription endpoint.";
        };

        groqUrl = mkOption {
          type = types.str;
          default = "https://api.groq.com/openai/v1/audio/transcriptions";
          description = "Groq's transcription endpoint.";
        };
      };

      config = mkIf cfg.enable {
        assertions = [
          {
            assertion = cfg.backendOrder != [ ];
            message = "mountainous.features.dictation.backendOrder must contain at least one backend";
          }
          {
            assertion = cfg.backendOrder == lib.unique cfg.backendOrder;
            message = "mountainous.features.dictation.backendOrder must not contain duplicates";
          }
        ];

        sops.secrets.groq-api-key = {
          owner = "simon";
          mode = "0400";
        };

        systemd.user.services.quickshell = {
          environment = {
            DICTATION_BACKEND_ORDER = lib.concatStringsSep "," cfg.backendOrder;
            DICTATION_ZAO_URL = cfg.zaoUrl;
            DICTATION_GROQ_URL = cfg.groqUrl;
            DICTATION_GROQ_KEY_FILE = config.sops.secrets.groq-api-key.path;
          };
          path = [
            pkgs.coreutils
            pkgs.pipewire
            dictation-submit
          ];
        };

        hjem.users.simon.files.".config/quickshell/mountainous/Dictation.qml".source =
          ./quickshell/Dictation.qml;
      };
    };

  # The feature is available to every desktop layer but enabled only on the
  # machine selected for the first implementation and manual verification.
  nixos.hosts.myoko.module.mountainous.features.dictation.enable = true;
}
