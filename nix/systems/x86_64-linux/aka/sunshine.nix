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

  makeOnConnect = resolution: pkgs.writeShellScript "onConnect-${resolution}" ''
    ${hyprctl} --instance 0 keyword monitor HDMI-A-2,${resolution},auto,2 &&
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
          name = "4K 60";
          prep-cmd = [
            {
              do = makeOnConnect "3840x2160@60";
              undo = "";
            }
          ];
          cmd = "${waitForDisconnect} ${onDisconnect}";
          exclude-global-prep-cmd = "false";
          auto-detach = "false";
          wait-all = "false";
        }

        {
          name = "FHD 120";
          prep-cmd = [
            {
              do = makeOnConnect "1920x1080@120";
              undo = "";
            }
          ];
          cmd = "${waitForDisconnect} ${onDisconnect}";
          exclude-global-prep-cmd = "false";
          auto-detach = "false";
          wait-all = "false";
        }

        {
          name = "ZFold 6 (Landscape)";
          prep-cmd = [
            {
              do = makeOnConnect "2160x1856@90";
              undo = "";
            }
          ];
          cmd = "${waitForDisconnect} ${onDisconnect}";
          exclude-global-prep-cmd = "false";
          auto-detach = "false";
          wait-all = "false";
        }

        {
          name = "Samsung Tab S9 (Landscape)";
          prep-cmd = [
            {
              do = makeOnConnect "2800x1752@90";
              undo = "";
            }
          ];
          cmd = "${waitForDisconnect} ${onDisconnect}";
          exclude-global-prep-cmd = "false";
          auto-detach = "false";
          wait-all = "false";
        }

        {
          name = "ThinkPad X1 Fold Gen 2 (Landscape)";
          prep-cmd = [
            {
              do = makeOnConnect "2560x1920@60";
              undo = "";
            }
          ];
          cmd = "${waitForDisconnect} ${onDisconnect}";
          exclude-global-prep-cmd = "false";
          auto-detach = "false";
          wait-all = "false";
        }

        {
          name = "ThinkPad X1 Fold Gen 2 (Portrait)";
          prep-cmd = [
            {
              do = makeOnConnect "1920x2560@60";
              undo = "";
            }
          ];
          cmd = "${waitForDisconnect} ${onDisconnect}";
          exclude-global-prep-cmd = "false";
          auto-detach = "false";
          wait-all = "false";
        }

        {
          name = "ThinkPad X1 Fold Gen 2 (Laptop)";
          prep-cmd = [
            {
              do = makeOnConnect "1920x1280@60";
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
