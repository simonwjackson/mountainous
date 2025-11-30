{
  config,
  lib,
  pkgs,
  cfg,
  ...
}: let
  inherit (lib) mkIf;

  logPath = "/tmp/sunshine.log";

  # Get monitor names from cfg.streaming.monitors
  primaryMonitor = cfg.streaming.monitors.primary;
  virtualMonitor = cfg.streaming.monitors.virtual;

  # Helper script to get Hyprland signature
  getHyprlandSignature = pkgs.writeShellScript "getHyprlandSignature" ''
    ${pkgs.findutils}/bin/find "$XDG_RUNTIME_DIR/hypr/" -maxdepth 1 -type d |
      ${pkgs.gnugrep}/bin/grep -v "^$XDG_RUNTIME_DIR/hypr/$" |
      ${pkgs.gawk}/bin/awk -F'/' '{print $NF}'
  '';

  # Wait for client disconnect from sunshine logs
  waitForDisconnect = pkgs.writeShellScript "waitForDisconnect" ''
    ${pkgs.coreutils}/bin/tail -n 0 -f "${logPath}" |
      ${pkgs.gnugrep}/bin/grep -q "CLIENT DISCONNECTED" && $1
  '';

  # Script to run when client disconnects - switch back to primary monitor
  onDisconnect = pkgs.writeShellScript "onDisconnect" ''
    export PATH="${pkgs.hyprland}/bin:$PATH"

    HYPRLAND_INSTANCE_SIGNATURE=$(${getHyprlandSignature})
    export HYPRLAND_INSTANCE_SIGNATURE

    hyprctl dispatch dpms on ${primaryMonitor}
    hyprctl dispatch moveworkspacetomonitor 2 ${primaryMonitor} &&
      hyprctl dispatch workspace 2 &&
      hyprctl dispatch dpms off ${virtualMonitor}
  '';

  # Script to run when client connects - switch to virtual monitor
  onConnect = pkgs.writeShellScript "onConnect" ''
    export PATH="${pkgs.hyprland}/bin:$PATH"

    HYPRLAND_INSTANCE_SIGNATURE=$(${getHyprlandSignature})
    export HYPRLAND_INSTANCE_SIGNATURE

    hyprctl dispatch dpms on ${virtualMonitor}
    hyprctl dispatch moveworkspacetomonitor 2 ${virtualMonitor} &&
      hyprctl dispatch workspace 2 &&
      hyprctl dispatch dpms off ${primaryMonitor}
  '';
in {
  config = mkIf cfg.streaming.enable {
    # Configure Sunshine streaming service
    services.sunshine = {
      enable = true;
      capSysAdmin = true;
      openFirewall = true;
      autoStart = true;

      settings = {
        log_path = logPath;
        output_name = 0;
        key_rightalt_to_key_win = "enabled";
      };

      # Default application configuration with monitor switching
      applications = {
        env = {
          PATH = "$(PATH):$(HOME)/.local/bin";
        };
        apps =
          [
            {
              name = "Gaming";
              prep-cmd = [
                {
                  do = onConnect;
                  undo = "";
                }
              ];
              cmd = "${waitForDisconnect} ${onDisconnect}";
              exclude-global-prep-cmd = "false";
              auto-detach = "false";
              wait-all = "false";
            }
          ]
          # Append any user-defined applications from cfg.streaming.applications
          ++ cfg.streaming.applications;
      };
    };

    # Udev rules for uinput device access (may overlap with base gaming, but safe)
    services.udev.extraRules = ''
      KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
      KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess"
    '';
  };
}
