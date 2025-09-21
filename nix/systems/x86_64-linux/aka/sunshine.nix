{
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkForce;

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

  makeOnConnect = {
    resolution,
    scaling ? 1,
  }:
    pkgs.writeShellScript "onConnect-${resolution}-${toString scaling}" ''
      ${hyprctl} --instance 0 keyword monitor HDMI-A-2,${resolution},auto,${toString scaling} &&
        ${hyprctl} --instance 0 dispatch dpms on
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
              do = makeOnConnect {
                resolution = "3840x2160@60";
                scaling = 1;
              };
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
              do = makeOnConnect {
                resolution = "1920x1080@120";
                scaling = 1;
              };
              undo = "";
            }
          ];
          cmd = "${waitForDisconnect} ${onDisconnect}";
          exclude-global-prep-cmd = "false";
          auto-detach = "false";
          wait-all = "false";
        }

        {
          name = "ZFold 6 (Portrait)";
          prep-cmd = [
            {
              do = makeOnConnect {
                resolution = "1856x2160@90";
                scaling = 2;
              };
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
              do = makeOnConnect {
                resolution = "2160x1856@90";
                scaling = 2;
              };
              undo = "";
            }
          ];
          cmd = "${waitForDisconnect} ${onDisconnect}";
          exclude-global-prep-cmd = "false";
          auto-detach = "false";
          wait-all = "false";
        }

        {
          name = "Samsung Tab S9 (Portrait)";
          prep-cmd = [
            {
              do = makeOnConnect {
                resolution = "1752x2800@90";
                scaling = 2;
              };
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
              do = makeOnConnect {
                resolution = "2800x1752@90";
                scaling = 2;
              };
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
              do = makeOnConnect {
                resolution = "2560x2024@60";
                scaling = 1.5;
              };
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
              do = makeOnConnect {
                resolution = "2560x2024@60";
                scaling = 1.5;
              };
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
              do = makeOnConnect {
                resolution = "2560x1240@60";
                scaling = 1.5;
              };
              undo = "";
            }
          ];
          cmd = "${waitForDisconnect} ${onDisconnect}";
          exclude-global-prep-cmd = "false";
          auto-detach = "false";
          wait-all = "false";
        }

        {
          name = "ZFold 6 Folded (Portrait)";
          prep-cmd = [
            {
              do = makeOnConnect {
                resolution = "968x2376@90";
                scaling = 1.25;
              };
              undo = "";
            }
          ];
          cmd = "${waitForDisconnect} ${onDisconnect}";
          exclude-global-prep-cmd = "false";
          auto-detach = "false";
          wait-all = "false";
        }

        {
          name = "ZFold 6 Folded (Landscape)";
          prep-cmd = [
            {
              do = makeOnConnect {
                resolution = "2376x968@90";
                scaling = 1.25;
              };
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
