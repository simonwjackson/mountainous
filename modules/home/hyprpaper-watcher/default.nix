{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.mountainous.hyprpaper-watcher;
in {
  options.mountainous.hyprpaper-watcher = {
    enable = lib.mkEnableOption "Whether to enable";

    image = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/.cache/wallpapers/watched-image.png";
      description = "Path to the input image that will be processed";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services = {
      hyprpaper-watcher = {
        Unit = {
          Description = "Custom Wallpaper Processing Service";
          After = ["graphical-session.target" "hyprpaper.service"];
          Requires = ["hyprpaper.service"];
          PartOf = ["graphical-session.target"];
          BindsTo = ["hyprpaper.service"];
        };

        Install = {
          WantedBy = ["graphical-session.target"];
        };

        Service = {
          Type = "simple";
          Restart = "always";
          RestartSec = 2;
          # Add environment variable for HOME
          Environment = "HOME=%h";
          ExecStart = let
            dependencies = with pkgs; [
              bash
              coreutils
              entr
              hyprland
              jq
            ];

            script = pkgs.writeShellApplication {
              name = "hyprpaper-watcher";
              runtimeInputs = dependencies;
              text = ''
                #!/usr/bin/env bash

                IMAGE=$(eval echo "${cfg.image}")

                # Create directory if it doesn't exist
                mkdir -p "$(dirname "$IMAGE")"

                # Ensure input image exists (create if needed)
                if [ ! -f "$IMAGE" ]; then
                  touch "$IMAGE"
                fi

                # Wait for Hyprland to be ready
                while ! hyprctl monitors &>/dev/null; do
                  echo "Waiting for Hyprland to be ready..."
                  sleep 1
                done

                create_wallpaper_commands() {
                  hyprctl monitors -j |
                    jq -r '.[].name' |
                    while read -r monitor; do
                      echo -n "hyprctl hyprpaper wallpaper \"$monitor,$IMAGE\" && "
                    done
                }

                # Main loop using entr with explicit error handling
                while true; do
                  if ! echo "$IMAGE" | entr -n bash -c "
                    hyprctl hyprpaper unload all || true
                    hyprctl hyprpaper preload '$IMAGE' && \
                    $(create_wallpaper_commands) true
                  "; then
                    echo "entr command failed, retrying in 2 seconds..."
                    sleep 2
                  fi
                done
              '';
            };
          in "${script}/bin/hyprpaper-watcher";
        };
      };

      hyprpaper = {
        Unit = {
          Description = "Hyprpaper Wallpaper Daemon";
          After = ["graphical-session-pre.target"];
          Wants = ["graphical-session-pre.target"];
          PartOf = ["graphical-session.target"];
        };

        Install = {
          WantedBy = ["graphical-session.target"];
        };

        Service = {
          Type = "simple";
          Restart = "always";
          RestartSec = 2;
          Environment = "HOME=%h";
          ExecStart = let
            hyprpaperConfig = pkgs.writeText "hyprpaper.conf" ''
              ipc = on
            '';
          in "${pkgs.hyprpaper}/bin/hyprpaper -c ${hyprpaperConfig}";
        };
      };
    };
  };
}
