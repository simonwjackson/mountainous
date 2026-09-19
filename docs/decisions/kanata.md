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
