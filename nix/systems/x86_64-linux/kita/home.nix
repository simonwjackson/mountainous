{pkgs, ...}: {
  mountainous.hyprland = {
    enable = true;
  };

  # Additional packages specific to this system
  home.packages = with pkgs; [
    neovim
    ex # Example extraction utility package from packages directory
  ];

  # System-specific settings
  programs.git.extraConfig = {
    init.defaultBranch = "main";
  };

  # Converted kanshi config to home-manager nix config
  services.kanshi = {
    enable = true;
    profiles = {
      undocked = {
        exec = [
          "${pkgs.hyprland}/bin/hyprctl --instance 0 keyword monitor eDP-1,1920x1080@120,auto,1.25 && ${pkgs.coreutils}/bin/sleep 0.5 && ${pkgs.hyprland}/bin/hyprctl --instance 0 dispatch workspace 2"
        ];
        outputs = [
          {
            criteria = "eDP-1";
            status = "enable";
          }
        ];
      };

      nreal = {
        exec = [
          "${pkgs.hyprland}/bin/hyprctl --instance 0 keyword monitor eDP-1,disabled && ${pkgs.hyprland}/bin/hyprctl --instance 0 keyword monitor desc:Nreal nreal air 0x88888800,1920x1080@60,auto,1.25 && ${pkgs.coreutils}/bin/sleep 0.5 && ${pkgs.hyprland}/bin/hyprctl --instance 0 dispatch workspace 2"
        ];
        outputs = [
          {
            criteria = "eDP-1";
            status = "disable";
          }
          {
            criteria = "Nreal nreal air 0x88888800";
            status = "enable";
          }
        ];
      };

      docked = {
        exec = [
          "${pkgs.hyprland}/bin/hyprctl --instance 0 keyword monitor eDP-1,disabled && ${pkgs.hyprland}/bin/hyprctl --instance 0 keyword monitor DP-6,2880x1800@120,0x1200,1.5 && ${pkgs.hyprland}/bin/hyprctl --instance 0 keyword monitor DP-7,2880x1800@120,0x0,1.5 && ${pkgs.hyprland}/bin/hyprctl --instance 0 dispatch workspace 1"
        ];
        outputs = [
          {
            criteria = "eDP-1";
            status = "disable";
          }
          {
            # INFO: Using DP-6 and DP-7 as "unique" identifiers since they are identical devices
            criteria = "DP-6";
            status = "enable";
          }
          {
            criteria = "DP-7";
            status = "enable";
          }
        ];
      };
    };
  };
}
