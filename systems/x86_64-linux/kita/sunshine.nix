{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption mkEnableOption types hasAttr isBool genAttrs;

  logPath = "/tmp/sunshine.log";
  primaryMonitor = "DP-1";
  virtualMonitor = "HDMI-A-2";
  getHyprlandSignature = pkgs.writeShellScript "getHyprlandSignature" ''
    ${pkgs.findutils}/bin/find "$XDG_RUNTIME_DIR/hypr/" -maxdepth 1 -type d |
      ${pkgs.gnugrep}/bin/grep -v "^$XDG_RUNTIME_DIR/hypr/$" |
      ${pkgs.gawk}/bin/awk -F'/' '{print $NF}'
  '';

  waitForDisconnect = pkgs.writeShellScript "waitForDisconnect" ''
    ${pkgs.coreutils}/bin/tail -n 0 -f "${logPath}" |
      ${pkgs.gnugrep}/bin/grep -q "CLIENT DISCONNECTED" && $1
  '';

  onConnect = pkgs.writeShellScript "onConnect" ''
    export PATH="${pkgs.hyprland}/bin:$PATH"

    HYPRLAND_INSTANCE_SIGNATURE=$(${getHyprlandSignature})
    export HYPRLAND_INSTANCE_SIGNATURE

    hyprctl dispatch dpms on DP-2
    hyprctl dispatch moveworkspacetomonitor 2 DP-2 &&
      hyprctl dispatch workspace 2 &&
      hyprctl dispatch dpms off eDP-1
  '';

  onDisconnect = pkgs.writeShellScript "onDisconnect" ''
    export PATH="${pkgs.hyprland}/bin:$PATH"

    HYPRLAND_INSTANCE_SIGNATURE=$(${getHyprlandSignature})
    export HYPRLAND_INSTANCE_SIGNATURE

    hyprctl dispatch dpms on eDP-1
    hyprctl dispatch moveworkspacetomonitor 2 eDP-1 &&
      hyprctl dispatch workspace 2 &&
      hyprctl dispatch dpms off DP-2
  '';
in {
  services.sunshine = {
    enable = true;
    settings = {
      output_name = 0;
    };
    applications = {
      env = {
        PATH = "$(PATH):$(HOME)/.local/bin";
      };
      apps = lib.mkAfter [
        {
          name = "Desktop";
          exclude-global-prep-cmd = "false";
          auto-detach = "false";
          wait-all = "false";
        }
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
      ];
    };
  };
}
