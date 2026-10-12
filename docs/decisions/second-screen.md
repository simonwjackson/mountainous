# Second screen

Myoko streams a second Hyprland monitor to an Android tablet running
Moonlight. The tablet sits below the laptop, so the monitor sits below the
panel. It exists only while the tablet is connected. Connecting and
disconnecting need no other action.

## What happens

1. Moonlight starts the "Second screen" app on Myoko.
2. Sunshine runs `mountainous-second-screen attach`. It creates the headless
   output `SUNSHINE` at the size Moonlight asked for. It scales it so its
   logical height matches the panel's, and puts it centred under the panel.
   It refuses to finish until Hyprland reports exactly that size, scale and
   position.
3. Sunshine captures `SUNSHINE` with wlr-screencopy and encodes it on the
   Iris Xe with VA-API.
4. Moonlight disconnects, or quits the app.
   - Quit: Sunshine stops the app and runs `detach`.
   - Disconnect: `hold`, the app's command, watches Sunshine's log. After 15
     seconds with no client it runs `detach` and exits. A tablet back inside
     the 15 seconds keeps its screen as it was.
5. `detach` removes `SUNSHINE`. Hyprland moves each of its pages to the panel
   (`CMonitor::onDisconnect`), and the strip code renumbers them to follow
   the panel's pages.

`hold` removes the output itself because Sunshine notices that an app has
exited only when something asks it. While a client streams, the control loop
asks every 150 ms. After the last client leaves, nothing asks until Moonlight
polls again.

## Choices

| Choice | Taken | Why | Cost |
| --- | --- | --- | --- |
| Output | Headless output made per connection | Fits the tablet's own resolution. Nothing exists when no tablet is attached. | The output is new each time. Hyprland does not keep pages on it between connections. |
| Placement | Scaled to the panel's logical height, centred below | Text is a similar size on both screens. The pointer moves straight down. | A tablet much wider than the panel starts at its left edge, so it is not centred. |
| Capture | `wlr` | The only capture that sees a headless output. Needs no `CAP_SYS_ADMIN`. | Copies through the compositor, with slightly more latency than KMS. |
| Encoder | VA-API on `/dev/dri/renderD128` | Iris Xe encodes H.264 and HEVC. A 2960x1848 HEVC test encode ran at 74 fps. | No 4:4:4. Sunshine's VA-API encoder does not offer it, so text has 4:2:0 colour edges. |
| Audio | `stream_audio = disabled` | Sound stays on the laptop. Sunshine's own docs suggest this for second monitors. | The tablet plays no sound. |
| Network | Tailscale only | Works from anywhere. No LAN ports open. | WireGuard adds a little latency. Avahi is off, so Moonlight does not find Myoko on its own. |
| Version | `nixpkgs-sunshine` input, `nixos-unstable` | Sunshine 2026.914.233613 fixes GHSA-fp6g-27w5-489j. The system pin had 2026.516.143833. | A second nixpkgs to download for one package. |

## Pages on two monitors

Hyprland numbers pages across all monitors. The strip code in
`hyprland.lua` assumed one monitor. Four parts changed:

- Compaction never renames a page onto the id of an empty page that still
  exists. The tablet shows a page of its own, which can be empty.
- An overflow window goes past every page, empty or not, so it never lands
  on the tablet's empty page.
- Closing the last window on one screen keeps focus on that screen.
- Page keys and directional focus walk the focused monitor's pages (`m+1`,
  not `e+1`).

`scripts/test-hyprland-session` checks these against a model of Hyprland
with two monitors.

## Input

- Keyboard and relative mouse need nothing.
- Absolute mouse: Sunshine scales positions across the whole desktop, and
  Hyprland maps an unbound absolute pointer across the whole layout. These
  agree only while no monitor sits left of or above zero. Placement keeps x
  and y at zero or more for that reason.
- Touch and pen: Sunshine reports positions from 0 to 1 across the streamed
  monitor. `second-screen.lua` binds `libvirtualhid-touchscreen` and
  `libvirtualhid-pen-tablet` to `SUNSHINE`, so a touch lands on the tablet's
  screen and not on the panel.

## First use

1. Open `https://myoko:47990` from a machine on the tailnet. Set the Sunshine
   user name and password.
2. In Moonlight on the tablet, add a PC by Myoko's tailnet name or
   100.117.218.54.
3. Enter the PIN that Moonlight shows in the web page's PIN tab.
4. In Moonlight settings, set the resolution to the tablet's native one and
   60 fps. Start "Second screen".

## Known issues

- First deploy: the udev rules that let Sunshine create input devices
  apply to `/dev/uinput` and `/dev/uhid` only after a reboot or
  `udevadm trigger --action=change` on both. Until then Sunshine logs
  `virtualhid-not-available`.
- One start on 2026-10-12 died with "Address already in use" on port
  47990 while nothing held the port. It did not happen again in five
  restarts. The service now restarts after any exit.

## When Tailscale is too slow

The fallback is a direct Wi-Fi link. Open the same ports on that interface
in `modules/sunshine.nix` (`networking.firewall.interfaces.<name>`). Nothing
else changes.
