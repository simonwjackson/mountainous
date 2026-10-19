# Keyboard Remapping with Kanata

## Purpose
Hardware-level keyboard remapping below the compositor, porting the home-row mods from `simonwjackson/zmk-config` (Corne keyboard) to laptop and external keyboards.

## Layer Layout
- Hold `A` -> DIR (arrows, navigation, function keys)
- Hold `S` -> NUM (numpad under right hand, symbols)
- Hold `D` -> WRP (bracket pairs)
- Hold `F` -> CHK (backspace, tab, shift-tab, delete)
- Left Alt and Left Meta are swapped, placing Hyprland `SUPER` adjacent to spacebar.

## Adaptations from Corne to Standard Layout
1. **Per-Finger Timings**: Ported from Corne ZMK configuration. ZMK's `flavor = "balanced"` maps to Kanata's `tap-hold-release`.
2. **Row 3 Offset**: Row 3 positions on the Corne differ from standard stagger. Corne `M N B` maps to laptop `m , .` by physical position rather than character code to preserve numpad ergonomics.
3. **Keypad Shift Codes**: Standard keypad codes require NumLock. Shifted number-row codes (`+`, `*`) are emitted directly.
4. **Hotplug Device Grabbing**: Kanata 1.12.0 does not reliably detect newly connected keyboards without a service restart. A udev rule triggers `kanata-regrab.service` (debounced via sleep) on keyboard device insertion.
5. **Combos (Chords)**: Pressing `jk` or `kj` quickly produces `Enter` (`ret`). Pressing `kl` or `lk` quickly produces `Escape` (`esc`). These are implemented with `defchordsv2` using a 150ms timeout and `first-release`. `concurrent-tap-hold yes` is enabled in `defcfg`. The combos are disabled on sub-layers (`dir`, `pag`, `fun`, `num`, `sym`, `wrp`, `chk`) so arrow movement, bracket insertion, and number typing are not interrupted.
6. **Dead Editing Keys**: The physical Tab, Escape, Enter, and Backspace keys are inert on the base layer. Each function keeps a channel. Enter comes from the `jk` and `kj` chords, Escape from the `kl` and `lk` chords, Backspace from hold `F` then `h`, and Tab from hold `F` then `j`. The keys map to `f24`, not `XX`, because a key mapped to `XX` breaks the next tap-hold on kanata 1.12.0. The greetd password prompt takes Enter only from the `jk` chord.
7. **Bottom Row Offset**: The bottom-row letters sit one key to the right of their labels. The physical `z` key types `x`, `x` types `c`, `c` taps `v`, and the physical Left Shift key taps `z`. Holding `c` still yields Left Shift, and holding Left Shift yields Left Ctrl, so the row keeps both modifiers.
8. **Inert Outer, Number, and Unused Physical Keys**: The physical number row (`1` through `0`, `-`, `=`, `` ` ``), brackets (`[`, `]`), backslash (`\`), apostrophe (`'`), right shift (`rsft`), function keys (`f1` through `f12`), and physical `b` map to `@dead` (`f24`) on the base layer. Numbers and symbols are accessed via the `num`, `sym`, and `wrp` layers; function keys via the `fun` layer; shift via held `c` or held `m`; and `b` via physical period (`.`).
9. **Extended Bottom Row Remapping**:
   - Physical `v` types comma (`,`).
   - Physical `b` is inert (`@dead`).
   - Physical `n` types period (`.`).
   - Physical comma (`,`) types `n`.
   - Physical period (`.`) types `b`.
   - Physical slash (`/`) taps apostrophe (`'`) and holds Left Ctrl (`lctl`), preserving the right-hand pinky control modifier.

## Tablet Mode on Convertibles
Kanata 1.12.0 creates its output device with bus type i8042 (`linux-output-device-bus-type` defaults to `I8042`). libinput's `[Serial Keyboards]` quirk therefore tags the kanata device `AttrKeyboardIntegration=internal`, and suspends it when the tablet-mode switch turns on. Every keyboard types through that one device, so on Myoko a fold to 360 degrees also killed external keyboards (verified 2026-10-18 with `libinput quirks list` on Myoko's `event1`).

The fix has two halves:
- `/etc/libinput/local-overrides.quirks` sets `ModelTabletModeNoSuspend=1` on the device named `kanata`. The `internal` tag stays, because disable-while-typing pairs only internal keyboards with the touchpad. A `USB` bus type would fix tablet mode but break disable-while-typing, so it is rejected.
- `kanata-tablet-mode.service` (`modules/kanata-tablet-mode.py`) watches every `SW_TABLET_MODE` switch and writes `1` to the kernel `inhibited` flag of each i8042 keyboard except kanata's. The kernel then drops the built-in keyboard's events before kanata reads them. A udev rule starts the service when a switch appears, because intel-hid can create its switch only at the first fold. `ExecStopPost` writes `0`, so a stopped watcher never leaves the built-in keyboard dead.
