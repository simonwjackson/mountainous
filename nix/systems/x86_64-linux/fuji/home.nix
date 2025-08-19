{pkgs, ...}: {
  mountainous = {
    agenix.enable = true;
    hyprland = {
      enable = true;
      extraSettings = {
        monitor = [
          # External monitor (DP-1) - normal orientation, positioned above
          "DP-3,2880x1800@120,0x0,1.6,transform,0"
          "DP-2,2880x1800@120,0x0,1.6,transform,0"
          "DP-1,2880x1800@120,0x0,1.6,transform,0"

          # Internal display (eDP-1) - 270° rotation, centered below external
          "eDP-1,2024x2560@60,100x1125,1.6,transform,3"

          # Fallback for any other monitors
          ",preferred,auto,1.0"
        ];
      };
    };
    firefox = {
      enable = true;

      # Your active Firefox extensions
      extensions = {
        # Essential security & privacy
        "uBlock0@raymondhill.net" = {slug = "ublock-origin";};
        "addon@darkreader.org" = {slug = "darkreader";};
        "{d634138d-c276-4fc8-924b-40a0ea21d284}" = {slug = "1password-x-password-manager";};

        # Developer tools
        "{5caff8cc-3d2e-4110-a88a-003cc85b3858}" = {slug = "vue-js-devtools";};
        "{6AC85730-7D0F-4de0-B3FA-21142DD85326}" = {slug = "colorzilla";};

        # Productivity
        "sponsorBlocker@ajay.app" = {slug = "sponsorblock";};
        "languagetool-webextension@languagetool.org" = {slug = "languagetool";};
        "{1c5e4c6f-5530-49a3-b216-31ce7d744db0}" = {slug = "markdownload";};
        "team@readwise.io" = {slug = "readwise-highlighter";};

        # Utilities
        "FirefoxColor@mozilla.com" = {slug = "firefox-color";};
        "autotextexpander@example.com" = {slug = "auto-text-expander";};
        "jid1-BYcQOfYfmBMd9A@jetpack" = {slug = "pushbullet";};
        "Toggley@FaridZelli" = {slug = "toggley";};
        "{44df5123-f715-9146-bfaa-c6e8d4461d44}" = {slug = "fakespot-fake-reviews-amazon";};

        # Vim navigation
        "tridactyl.vim.betas@cmcaine.co.uk" = {slug = "tridactyl-vim";};
      };

      # Optional: Additional Firefox policies
      extraPolicies = {
        DisableTelemetry = true;
        DisableFirefoxStudies = true;
        DisablePocket = true;
      };
    };
  };

  # System-specific settings
  programs.git.extraConfig = {
    init.defaultBranch = "main";
  };

  programs.direnv.enable = true;

  # Configure XDG portal to use GTK file picker
  xdg.configFile."xdg-desktop-portal/hyprland-portals.conf".text = ''
    [preferred]
    default=hyprland;gtk
    org.freedesktop.impl.portal.FileChooser=gtk
  '';

  home.packages = with pkgs; [
    # Move later
    windsurf
    code-cursor

    neovim
    ex # Example extraction utility package from packages directory
  ];

  # Kanshi configuration for display profile management
  # services.kanshi = {
  #   enable = true;
  #   settings = [
  #     {
  #       profile = {
  #         name = "undocked";
  #         outputs = [
  #           {
  #             criteria = "eDP-1";
  #             status = "enable";
  #           }
  #         ];
  #         exec = [
  #           "${pkgs.hyprland}/bin/hyprctl --instance 0 keyword monitor eDP-1,1920x1080@120,auto,1.25 && ${pkgs.coreutils}/bin/sleep 0.5 && ${pkgs.hyprland}/bin/hyprctl --instance 0 dispatch workspace 2"
  #         ];
  #       };
  #     }

  #     {
  #       profile = {
  #         name = "nreal";
  #         outputs = [
  #           {
  #             criteria = "eDP-1";
  #             status = "disable";
  #           }
  #           {
  #             criteria = "Nreal nreal air 0x88888800";
  #             status = "enable";
  #           }
  #         ];
  #         exec = [
  #           "${pkgs.hyprland}/bin/hyprctl --instance 0 keyword monitor eDP-1,disabled && ${pkgs.hyprland}/bin/hyprctl --instance 0 keyword monitor desc:Nreal nreal air 0x88888800,1920x1080@60,auto,1.25 && ${pkgs.coreutils}/bin/sleep 0.5 && ${pkgs.hyprland}/bin/hyprctl --instance 0 dispatch workspace 2"
  #         ];
  #       };
  #     }

  #     {
  #       profile = {
  #         name = "docked";
  #         outputs = [
  #           {
  #             criteria = "eDP-1";
  #             status = "disable";
  #           }
  #           {
  #             # INFO: Using DP-6 and DP-7 as "unique" identifiers since they are identical devices
  #             criteria = "DP-6";
  #             status = "enable";
  #           }
  #           {
  #             criteria = "DP-7";
  #             status = "enable";
  #           }
  #         ];
  #         exec = [
  #           "${pkgs.hyprland}/bin/hyprctl --instance 0 keyword monitor eDP-1,disabled && ${pkgs.hyprland}/bin/hyprctl --instance 0 keyword monitor DP-6,2880x1800@120,0x1200,1.5 && ${pkgs.hyprland}/bin/hyprctl --instance 0 keyword monitor DP-7,2880x1800@120,0x0,1.5 && ${pkgs.hyprland}/bin/hyprctl --instance 0 dispatch workspace 1"
  #         ];
  #       };
  #     }
  #   ];
  # };
}
