{
  config,
  lib,
  pkgs,
  ...
}: let
  # The real steam binary from programs.steam (with extraCompatPackages etc),
  # NOT the gaming module's steam-cage wrapper.
  steamPkg = config.programs.steam.package;

  # Steam kiosk session: sway with Steam in normal mode
  # NOTE: Steam is NOT launched in Big Picture mode
  steamKioskSession = pkgs.writeShellApplication {
    name = "steam-kiosk-session";
    runtimeInputs = [
      pkgs.sway
      pkgs.foot
      pkgs.coreutils
      pkgs.dbus
    ];
    text = ''
      export XDG_CURRENT_DESKTOP=sway
      export XDG_SESSION_TYPE=wayland

      SWAY_CONFIG=$(mktemp --suffix=.sway-steam)
      trap 'rm -f "$SWAY_CONFIG"' EXIT

      cat >"$SWAY_CONFIG" <<EOF
      # Minimal sway config for Steam kiosk mode
      default_border none
      default_floating_border none
      titlebar_border_thickness 0
      titlebar_padding 0

      # AYANEO AIR: portrait-native panel, rotate to landscape
      # Zen kernel may report the connector as Unknown-1 instead of eDP-1
      output * transform 90

      # Hide cursor after 3 seconds of inactivity
      seat * hide_cursor 3000

      # Launch Steam directly (bypass gaming module's steam-cage wrapper)
      exec ${steamPkg}/bin/steam

      # Keybindings
      bindsym Mod4+Return exec foot
      bindsym Mod4+Shift+q kill
      bindsym Mod4+Shift+e exit
      EOF

      exec dbus-run-session sway -c "$SWAY_CONFIG"
    '';
  };
in {
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  networking.hostName = "ibuki";
  time.timeZone = "America/Denver";

  mountainous = {
    presets = {
      core.enable = true;
      portable.enable = true;
    };

    features = {
      device = {
        role = "kiosk";
        capabilities = {
          battery = true;
          formFactor = "handheld";
          touchscreen = true;
        };
      };

      # ── Hibernation (swap-sleep) ─────────────────────────────────────
      hibernation = {
        enable = true;
        resumeDevice = "/dev/disk/by-id/nvme-NVME_SSD_512GB_2208VC0S036H0498-part3";
        swap = {
          mode = "swapfile-btrfs";
          path = "/swap/swapfile";
        };
      };

      # ── Gaming ───────────────────────────────────────────────────────
      gaming.enable = true;

      # ── Connectivity ─────────────────────────────────────────────────
      bluetooth.enable = true;

      # ── Disable desktop features not needed for kiosk ────────────────
      codexbar.enable = false;
      dictation.enable = false;
      evdev-hotkey.enable = false;
      matrix-notifications.enable = false;
    };
  };

  # ── Greetd: auto-login to Steam kiosk session ───────────────────────
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${steamKioskSession}/bin/steam-kiosk-session";
      user = "simonwjackson";
    };
  };

  # ── Kernel ───────────────────────────────────────────────────────────
  boot.kernelPackages = pkgs.linuxPackages_zen;

  # ── Swap ─────────────────────────────────────────────────────────────
  # 16 GiB swapfile: must be >= RAM (12 GiB) for hibernate-to-disk
  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 16384;
    }
  ];

  # ── Users ────────────────────────────────────────────────────────────
  users.users.simonwjackson.extraGroups = [
    "networkmanager"
    "video"
    "input" # for gamepad / touchscreen access
  ];

  # ── microSD ownership ───────────────────────────────────────────────
  # Ensure the Steam library mount is owned by the gaming user
  systemd.tmpfiles.settings."10-tank-ownership" = {
    "/media/tank".d = {
      user = "simonwjackson";
      group = "users";
      mode = "0755";
    };
  };

  system.stateVersion = "24.11";
}
