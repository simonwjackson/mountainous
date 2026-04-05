{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  networking.hostName = "kita";
  time.timeZone = "America/Denver";

  mountainous = {
    presets = {
      core.enable = true;
      desktop.enable = true;
    };

    features = {
      device = {
        role = "kiosk";
        capabilities = {
          battery = false;
          formFactor = "tower";
          touchscreen = false;
        };
      };

      # Keep the kiosk image lean until we decide what extra desktop niceties
      # are actually useful on a TV-facing appliance.
      codexbar.enable = false;
      dictation.enable = false;
      evdev-hotkey.enable = false;
      matrix-notifications.enable = false;
    };
  };

  home-manager.users.simonwjackson = {
    home.packages = [pkgs.chromium];

    # Keep the TV/UI alive until we decide on idle/display policy for this box.
    services.hypridle.enable = lib.mkForce false;

    systemd.user.services.jellyfin-kiosk = {
      Unit = {
        Description = "Chromium Jellyfin kiosk";
        After = ["graphical-session.target"];
        PartOf = ["graphical-session.target"];
      };

      Service = {
        ExecStart = "${pkgs.chromium}/bin/chromium --enable-features=UseOzonePlatform --ozone-platform=wayland --kiosk --no-first-run --no-default-browser-check --disable-session-crashed-bubble --app=https://watch.hummingbird-lake.ts.net/web/";
        Restart = "always";
        RestartSec = 5;
      };

      Install.WantedBy = ["graphical-session.target"];
    };
  };

  users.users.simonwjackson.extraGroups = [
    "networkmanager"
    "video"
  ];

  system.stateVersion = "24.11";
}
