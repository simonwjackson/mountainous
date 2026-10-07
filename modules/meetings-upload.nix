# Upload meeting transcripts from ~/Downloads to the meetings store on Zao.
#
# A path unit runs the upload when ~/Downloads changes. Browsers write to a
# temporary name and rename the finished file, so the rename is the trigger.
# A timer retries every 15 minutes in case Zao was unreachable. A file is
# deleted only after Zao confirms it has the transcript.
{
  nixos.modules.desktop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.mountainous.features.meetings-upload;

      meetings-upload = pkgs.writeShellApplication {
        name = "meetings-upload";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.curl
        ];
        text = builtins.readFile ./meetings-upload.sh;
      };
    in
    {
      options.mountainous.features.meetings-upload = {
        enable = lib.mkEnableOption "upload downloaded meeting transcripts to Zao";

        user = lib.mkOption {
          type = lib.types.str;
          default = "simon";
          description = "User whose ~/Downloads is watched.";
        };

        url = lib.mkOption {
          type = lib.types.str;
          default = "https://meetings.hummingbird-lake.ts.net";
          description = "Base URL of the meetings store.";
        };
      };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [ meetings-upload ];

        systemd.user.services.meetings-upload = {
          description = "Upload downloaded meeting transcripts";
          unitConfig.ConditionUser = cfg.user;
          environment.MEETINGS_URL = cfg.url;
          serviceConfig = {
            Type = "oneshot";
            ExecStart = lib.getExe meetings-upload;
          };
        };

        systemd.user.paths.meetings-upload = {
          description = "Watch ~/Downloads for meeting transcripts";
          unitConfig.ConditionUser = cfg.user;
          pathConfig.PathChanged = "%h/Downloads";
          wantedBy = [ "default.target" ];
        };

        systemd.user.timers.meetings-upload = {
          description = "Retry meeting transcript uploads";
          unitConfig.ConditionUser = cfg.user;
          timerConfig = {
            OnStartupSec = "2min";
            OnUnitActiveSec = "15min";
          };
          wantedBy = [ "timers.target" ];
        };
      };
    };
}
