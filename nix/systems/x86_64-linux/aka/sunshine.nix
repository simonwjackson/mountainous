{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption mkEnableOption types hasAttr isBool genAttrs mkForce;

  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  journalctl = "${pkgs.systemd}/bin/journalctl";
  grep = "${pkgs.gnugrep}/bin/grep";

  waitForDisconnect = pkgs.writeShellScript "waitForDisconnect" ''
    ${journalctl} --user -u sunshine.service -f |
      ${grep} -q "CLIENT DISCONNECTED" && $1
  '';

  onDisconnect = pkgs.writeShellScript "onDisconnect" ''
    ${hyprctl} --instance 0 reload
  '';

  onConnect = pkgs.writeShellScript "onConnect" ''
    ${hyprctl} --instance 0 keyword monitor HDMI-A-2,2160x1856@90,auto,2 &&
      ${hyprctl} --instance 0 keyword monitor DP-1,disable &&
      ${hyprctl} --instance 0 keyword monitor DP-2,disable
  '';
in {
  services.sunshine = {
    enable = true;
    capSysAdmin = true;
    settings = {
      output_name = 0;
    };
    autoStart = true;
    applications = {
      env = {
        PATH = "$(PATH):$(HOME)/.local/bin";
      };
      apps = mkForce [
        {
          name = "Gamingx";
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

  services.udev.extraRules = ''
    KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
    KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess"
  '';  
}
