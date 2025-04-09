{
  config,
  pkgs,
  ...
}: {
  mountainous = {
    profiles = {
      base.enable = true;
      workspace.enable = true;
    };
    desktops.hyprland = {
      extraSettings = {
        monitor = [
          # "desc:YHB YHB02P25 0x20240901,1080x1920@60,auto,1,transform,1"
          # "desc:YMK EM160 0x00000001,modeline 2880 2912 2920 2980 1800 1808 1816 1824 652270 +hsync -vsync,auto,1.6,transform,0"
        ];
        exec-once = [
          "systemctl --user start hyprland-session.target"
        ];
      };
    };
  };

  # Converted kanshi config to home-manager nix config
  # services.kanshi = {
  #   enable = true;
  #   profiles = {
  #     undocked = {
  #       exec = [
  #         "${pkgs.hyprland}/bin/hyprctl --instance 0 dispatch dpms on"
  #         "${pkgs.coreutils}/bin/sleep 0.1 && ${pkgs.hyprland}/bin/hyprctl --instance 0 dispatch workspace 2"
  #       ];
  #       outputs = [
  #         {
  #           criteria = "YHB YHB02P25 0x20240901";
  #           status = "enable";
  #           scale = 1.5;
  #           mode = "1080x1920@60";
  #           transform = "90";
  #         }
  #       ];
  #     };
  #     docked = {
  #       exec = [
  #         "${pkgs.hyprland}/bin/hyprctl --instance 0 dispatch workspace 1"
  #       ];
  #       outputs = [
  #         {
  #           criteria = "YHB YHB02P25 0x20240901";
  #           status = "disable";
  #         }
  #         {
  #           criteria = "sisel muhendislik Typec monitor";
  #           status = "disable";
  #         }
  #         {
  #           criteria = "YMK EM160 0x00000001";
  #           status = "enable";
  #           scale = 1.5;
  #           mode = "2880x1800@120";
  #         }
  #       ];
  #     };
  #   };
  # };

  home = {
    homeDirectory = "/home/${config.home.username}";
    stateVersion = "24.11"; # WARN: Changing this might break things. Just leave it.
  };
}
