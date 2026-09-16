# Kanata: hardware-level keyboard remapping below the compositor.
#
# Kamoi specifies:
#   * Tap A to type A; hold A for 180ms to turn HJKL into arrow keys.
#   * Swap Left Alt and Left Meta so thumb navigation and window management
#     are ergonomic on standard PC laptop keyboards.
#
# Remapping lives in Kanata rather than Hyprland because timed hold-layers and
# key interception belong at the evdev/uinput layer, before keys reach Wayland.
{
  nixos.modules.desktop =
    {
      config,
      pkgs,
      ...
    }:
    {
      services.kanata = {
        enable = true;
        keyboards.all = {
          # Empty devices list lets Kanata discover and intercept all connected keyboards.
          devices = [ ];
          extraDefCfg = ''
            process-unmapped-keys yes
          '';
          config = ''
            (defsrc
              a
              h j k l
              lalt lmet
            )

            (defalias
              a-arr (tap-hold 180 180 a (layer-toggle arrows))
            )

            (deflayer base
              @a-arr
              h j k l
              lmet lalt
            )

            (deflayer arrows
              _
              left down up right
              lmet lalt
            )
          '';
        };
      };

      systemd.services.kanata-all.serviceConfig = {
        Restart = "always";
        RestartSec = "1";
      };

      # Kanata sometimes never grabs a keyboard that is plugged in while it is
      # running, and it never retries that device. Measured on ridge against
      # kanata 1.12.0: a device on a path kanata had previously held was
      # ignored for 40s while alone, and grabbed immediately after a restart.
      # It is not a permission race; udev applies group 'input' in 13-56ms and
      # kanata already waits 200ms.
      #
      # Restarting on keyboard arrival is the blunt fix that makes "any
      # keyboard" true. It costs roughly two seconds of unmapped input at the
      # moment you attach a keyboard, which is the moment you are least likely
      # to be typing.
      services.udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT_KEYBOARD}=="1", ATTRS{name}!="kanata", TAG+="systemd", ENV{SYSTEMD_WANTS}+="kanata-regrab.service"
      '';

      # try-restart, not restart: during boot the keyboards appear before
      # kanata starts, and try-restart is a no-op while it is inactive. That
      # turns what would be a restart per device at every boot into nothing.
      #
      # The sleep coalesces the burst a single USB keyboard produces, since one
      # keyboard usually registers several event nodes. oneshot means systemd
      # will not stack a second run while this one is still sleeping.
      systemd.services.kanata-regrab = {
        description = "Restart kanata so a newly attached keyboard is grabbed";
        serviceConfig = {
          Type = "oneshot";
          ExecStartPre = "${pkgs.coreutils}/bin/sleep 3";
          ExecStart = "${config.systemd.package}/bin/systemctl try-restart kanata-all.service";
        };
      };
    };
}
