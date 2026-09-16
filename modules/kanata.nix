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
    { ... }:
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
    };
}
