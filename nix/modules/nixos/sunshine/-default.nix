{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption mkEnableOption types hasAttr isBool genAttrs;

  # xdgRuntimeDir = "/run/user/1000";
  # XDG_RUNTIME_DIR="${xdgRuntimeDir}"
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

  onDisconnect = pkgs.writeShellScript "onDisconnect" ''
    export PATH="${pkgs.hyprland}/bin:$PATH"

    HYPRLAND_INSTANCE_SIGNATURE=$(${getHyprlandSignature})
    export HYPRLAND_INSTANCE_SIGNATURE

    hyprctl dispatch dpms on DP-1
    hyprctl dispatch moveworkspacetomonitor 2 DP-1 &&
      hyprctl dispatch workspace 2 &&
      hyprctl dispatch dpms off HDMI-A-2
  '';

  onConnect = pkgs.writeShellScript "onConnect" ''
    export PATH="${pkgs.hyprland}/bin:$PATH"

    HYPRLAND_INSTANCE_SIGNATURE=$(${getHyprlandSignature})
    export HYPRLAND_INSTANCE_SIGNATURE

    hyprctl dispatch dpms on HDMI-A-2
    hyprctl dispatch moveworkspacetomonitor 2 HDMI-A-2 &&
      hyprctl dispatch workspace 2 &&
      hyprctl dispatch dpms off DP-1
  '';

  cfg = config.mountainous.gaming.sunshine;
  sunshineConfig = config.services.sunshine;
in {
  options.mountainous.gaming.sunshine = {
    enable = mkEnableOption "Sunshine, a self-hosted game stream host for Moonlight";
    applications = mkOption {
      default = {};
      description = ''
        Configuration for applications to be exposed to Moonlight. If this is set, no configuration is possible from the web UI, and must be by the `settings` option.
      '';
      example = lib.literalExpression ''
        {
          env = {
            PATH = "$(PATH):$(HOME)/.local/bin";
          };
          apps = [
            {
              name = "1440p Desktop";
              prep-cmd = [
                {
                  do = "''${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-4.mode.2560x1440@144";
                  undo = "''${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-4.mode.3440x1440@144";
                }
              ];
              exclude-global-prep-cmd = "false";
              auto-detach = "true";
            }
          ];
        }
      '';
      type = types.submodule {
        options = {
          env = mkOption {
            default = {};
            description = ''
              Environment variables to be set for the applications.
            '';
            type = types.attrsOf types.str;
          };
          apps = mkOption {
            default = [];
            description = ''
              Applications to be exposed to Moonlight.
            '';
            type = types.listOf types.attrs;
          };
        };
      };
    };
  };

  config = mkIf cfg.enable {
    services.sunshine = {
      enable = true;
      openFirewall = true;
      capSysAdmin = true;
      settings = {
        log_path = logPath;
        output_name = 0;
        key_rightalt_to_key_win = "enabled";
      };
      autoStart = true;
      applications = lib.mkMerge [
        {
          env = {
            PATH = "$(PATH):$(HOME)/.local/bin";
          };
          apps = [
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
        }
        cfg.applications
      ];
    };

    services.udev.extraRules = ''
      KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
      KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess"
    '';

    # environment.systemPackages = [
    #   pkgs.sunshine
    # ];

    # security.wrappers = {
    #   sunshine = {
    #     owner = "root";
    #     group = "root";
    #     capabilities = "cap_sys_admin+p";
    #     source = "${pkgs.sunshine}/bin/sunshine";
    #   };
    # };
    #
    # systemd.user.services.sunshine = lib.mkForce {
    #   description = "sunshine";
    #   wantedBy = ["graphical-session.target"];
    #   serviceConfig = {
    #     ExecStart = "${config.security.wrapperDir}/sunshine";
    #     Restart = "always";
    #   };
    # };
  };
}
