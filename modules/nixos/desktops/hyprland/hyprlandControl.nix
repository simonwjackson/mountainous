{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types mkIf;

  cfg = config.mountainous.desktops.hyprlandControl;
in {
  options.mountainous.desktops.hyprlandControl = {
    enable = mkEnableOption "Hyprland Control service";
    port = mkOption {
      type = types.port;
      default = 9876;
      description = "Port on which the Hyprland Control server will listen";
    };
    package = mkOption {
      type = types.package;
      default = pkgs.writeShellScript "hyprland-control" ''
        # HACK:
        export XDG_RUNTIME_DIR="/run/user/1000"
        HYPRLAND_INSTANCE_SIGNATURE=$(${pkgs.findutils}/bin/find "$XDG_RUNTIME_DIR/hypr/" -maxdepth 1 -type d | ${pkgs.gnugrep}/bin/grep -v "^$XDG_RUNTIME_DIR/hypr/$" | ${pkgs.gawk}/bin/awk -F'/' '{print $NF}')
        export HYPRLAND_INSTANCE_SIGNATURE

        PORT=${toString cfg.port}
        RESPONSE_OK="HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n"
        RESPONSE_NOT_FOUND="HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\n\r\n"
        RESPONSE_BAD_REQUEST="HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\n\r\n"

        handle_request() {
          local method="$1"
          local path="$2"
          local query_string="$3"

          case "$method $path" in
          "GET /api/keyword/monitor/resolution")
            local monitor
            local width
            local height

            monitor=$(echo "$query_string" | ${pkgs.gnugrep}/bin/grep -oP 'monitor=\K[^&]*' || echo "")
            width=$(echo "$query_string" | ${pkgs.gnugrep}/bin/grep -oP 'width=\K[^&]*' || echo "")
            height=$(echo "$query_string" | ${pkgs.gnugrep}/bin/grep -oP 'height=\K[^&]*' || echo "")
            refresh=$(echo "$query_string" | ${pkgs.gnugrep}/bin/grep -oP 'refresh=\K[^&]*' || echo "")

            if [ -z "$monitor" ] || [ -z "$width" ] || [ -z "$height" ]; then
              echo -en "$RESPONSE_BAD_REQUEST"
              echo '{"error": "Missing monitor, width, or height parameters"}'
              return
            fi

            if ! [[ "$width" =~ ^[0-9]+$ ]] || ! [[ "$height" =~ ^[0-9]+$ ]]; then
              echo -en "$RESPONSE_BAD_REQUEST"
              echo '{"error": "Invalid width or height parameter"}'
              return
            fi

            echo -en "$RESPONSE_OK"
            ${pkgs.hyprland}/bin/hyprctl keyword monitor "''${monitor},''${width}x''${height}@''${refresh},auto"
            # >/dev/null 2>&1
            echo "{\"message\": \"Resolution changed\", \"monitor\": \"$monitor\", \"width\": $width, \"height\": $height}"
            ;;
          "GET /api/monitors")
            echo -en "$RESPONSE_OK"
            ${pkgs.hyprland}/bin/hyprctl monitors -j
            ;;
          "GET /api/dispatch")
            local command

            command=$(echo "$query_string" | ${pkgs.gnugrep}/bin/grep -oP 'command=\K[^&]*' || echo "")

            if [ -z "$command" ]; then
              echo -en "$RESPONSE_BAD_REQUEST"
              echo '{"error": "Missing command parameter"}'
              return
            fi

            echo -en "$RESPONSE_OK"
            decoded_command=$(echo "$command" | ${pkgs.gnused}/bin/sed 's/+/ /g' | ${pkgs.gnused}/bin/sed 's/%20/ /g' | ${pkgs.gnused}/bin/sed -e 's/\^#/%23/g' -e 's/%23/#/g')
            ${pkgs.hyprland}/bin/hyprctl dispatch "$decoded_command" >/dev/null 2>&1
            echo "{\"message\": \"Command executed\", \"command\": \"$decoded_command\"}"
            ;;
          *)
            echo -en "$RESPONSE_NOT_FOUND"
            echo '{"error": "Not Found"}'
            ;;
          esac
        }

        main() {
          echo "Starting Hyprland Control server on port $PORT..."
          ${pkgs.socat}/bin/socat TCP-LISTEN:"$PORT",reuseaddr,fork EXEC:"$0 handle",pty,raw,echo=0
        }

        if [ "''${1:-}" = "handle" ]; then
          read -r request_line
          method=$(echo "$request_line" | cut -d' ' -f1)
          request=$(echo "$request_line" | cut -d' ' -f2)
          path=$(echo "$request" | cut -d'?' -f1)
          query_string=$(echo "$request" | cut -s -d'?' -f2)
          handle_request "$method" "$path" "$query_string"
        else
          main
        fi
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.services.hyprland-control = {
      description = "Hyprland Control Service";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        ExecStart = cfg.package;
        Restart = "on-failure";
        # DynamicUser = true;
        # RuntimeDirectory = "hyprland-control";
        # RuntimeDirectoryMode = "0755";
        # StateDirectory = "hyprland-control";
        # StateDirectoryMode = "0700";
        # ProtectSystem = "strict";
        # PrivateDevices = true;
        # ProtectHome = true;
        # NoNewPrivileges = true;
      };
    };
  };
}
