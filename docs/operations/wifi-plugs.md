# Gincuky Wi-Fi plugs to ESPHome

The Gincuky plugs (Jiuheng JH-G01U, FCC ID 2AJTRG01U) are ESP8266 Tuya plugs (Espressif MAC prefixes seen: 5C:CF:7F, 68:C6:3A).
They are flashed over the air with tuya-convert, without opening them, and run
`esphome/gincuky-jh-g01u.yaml`. Home Assistant on Rakku adopts each one through
the ESPHome integration. They never talk to Tuya's cloud.

First plug, 2026-11-21: MAC `5C:CF:7F:E0:E6:E2`, factory firmware still on
tuya-convert's list. Its 1 MB original firmware is on Myoko in
`/root/tuya-backups/`.

## Build the image

```sh
esphome/build gincuky-jh-g01u
```

One image serves every plug. ESPHome adds the last three MAC bytes to the name,
so each plug arrives in Home Assistant as `gincuky-plug-xxxxxx`. Wi-Fi, API key
and OTA password are in `secrets/esphome.yaml` (master key only).

## Flash a new plug

tuya-convert needs root and a Wi-Fi radio that can run an access point. Myoko
has both (`ssh -F /dev/null root@myoko`); its Ethernet keeps SSH up while
`wlo1` is taken. Tate's `wlp6s0` serves as the second device that must join the
flashing network. The scripts are in `scripts/tuya-convert/`; copy them to the
host named in each one's header.

1. On Myoko as root, once: `build-image` builds the `localhost/tuya-convert`
   container in `/root/tuya-convert`.
2. Copy `firmware.bin` (437 KB, under tuya-convert's 512 KB limit) to
   `/root/tuya-convert/files/esphome.bin` on Myoko, then run `start`. It sets
   `wlo1` unmanaged, opens the firewall on it and starts the container in tmux
   session `tc`. `ctl` shows the screen; `ctl keys <keys>` types into it.
3. Accept the disclaimer (`ctl keys yes Enter`). Run `join-from-tate` on Tate.
4. Plug in the device and hold its button about 5 s until the LED blinks fast
   (EZ mode, about 2 Hz). Slow blink is AP mode; hold again to switch.
5. Press Enter in `tc`. The intermediate firmware comes up at 10.42.42.42 in
   under a minute and tuya-convert saves a backup.
6. Pick `esphome.bin`. The plug reboots onto the home Wi-Fi as ESPHome.
7. When done, `stop` returns `wlo1` to NetworkManager.

If tuya-convert times out, the plug's firmware is patched. Then flash it over
serial: open the front cap (welded; tap a thin blade into the front ring) and
use the module's GND, GPIO0, 3.3V, TX and RX pads.

## Update plugs that already run ESPHome

```sh
esphome/build gincuky-jh-g01u <plug-ip>
```

## Adopt in Home Assistant

```sh
esphome/adopt <plug-ip>
```

It runs the ESPHome config flow on Rakku with the API key from
`secrets/esphome.yaml`. The plug appears as `switch.gincuky_plug_xxxxxx`.

Rename a plug (device name and entity ID): `esphome/rename <mac-suffix> "<Name>"`.

| MAC | Name | Entity |
|---|---|---|
| 5C:CF:7F:E0:E6:E2 | Christmas Tree | `switch.christmas_tree` |
| 5C:CF:7F:E0:E7:50 | Under Cabinet Far (Kitchen) | `switch.under_cabinet_far`, shown as `light.kitchen_under_cabinet_far` in the Under Cabinet group; replaced Zigbee plug 00:12:4b:00:22:69:99:81 |
| 68:C6:3A:9D:51:F3 | Dining Room Christmas Lights (Dining) | `switch.dining_room_christmas_lights` |
| 5C:CF:7F:71:A5:B8 | Family Room Christmas Lights (Family Room) | `switch.family_room_christmas_lights` |
