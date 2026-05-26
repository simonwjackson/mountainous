{pkgs, ...}: let
  jellyfinKioskSession = pkgs.writeShellApplication {
    name = "jellyfin-kiosk-session";
    runtimeInputs = [
      pkgs.cage
      pkgs.chromium
      pkgs.dbus
    ];
    text = ''
      export NIXOS_OZONE_WL=1
      export XDG_CURRENT_DESKTOP=cage
      export XDG_SESSION_TYPE=wayland

      exec dbus-run-session cage -- chromium \
        --enable-features=UseOzonePlatform \
        --ozone-platform=wayland \
        --kiosk \
        --no-first-run \
        --no-default-browser-check \
        --disable-session-crashed-bubble \
        --app=https://watch.hummingbird-lake.ts.net/web/
    '';
  };
in {
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  networking.hostName = "kita";
  time.timeZone = "America/Denver";

  mountainous = {
    presets = {
      core.enable = true;
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

  hardware.graphics.enable = true;

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${jellyfinKioskSession}/bin/jellyfin-kiosk-session";
      user = "simonwjackson";
    };
  };

  users.users.simonwjackson.extraGroups = [
    "networkmanager"
    "video"
  ];

  system.stateVersion = "24.11";
}
