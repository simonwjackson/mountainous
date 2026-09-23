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
10. **Fast Shift and GUI After Typing**: On Myoko, a timed uinput keyboard passed through the running Kanata 1.12.0 service. A key pressed 30ms before physical `c` or `m` caused Kanata to emit `v` or `m` instead of Shift. This also happened when `c` stayed down for 250ms. Shift registered after 150ms of prior idle. Held Space after 30ms of prior idle emitted a space instead of GUI, even after a 450ms hold. GUI registered after 320ms of prior idle. Physical Left Alt emitted GUI after 30ms. These results isolate the old 125ms Shift and 300ms Space `require-prior-idle` guards in the synthetic path. They do not rule out a separate physical keyboard fault.

   The user chose to remove both guards. The Shift tapping term remains 200ms. The first trial kept Space's plain `tap-hold` and 400ms term. Eight regression checks passed, but the user reported that GUI still took too long. A new 275ms hold check reproduced the delay: Kanata emitted a space, not GUI. The user chose a 250ms term for a second trial. With the new runtime config, the 275ms hold emitted GUI and a quick 80ms space still emitted a space. All nine timed checks passed. The earlier test on Hiyori found that a heavy ordinary space could misfire at 250ms. The user then asked for 100ms. A temporary 100ms trial emitted GUI instead of a quick space held about 105ms. The trial rolled back to 250ms automatically. The user chose a 150ms trial next. On Myoko, all eleven timed checks passed with the temporary 150ms config. A 175ms hold emitted GUI, while a space held 110ms and released 25ms later still emitted a space. Normal human typing at 150ms has not been checked. **Cost**: a fast roll through physical `c` or `m` can now lose the intended `v` or `m` and emit Shift. An ordinary space held for 150ms can trigger GUI shortcuts. `SUPER+C` closes the focused window. Run `scripts/test-kanata-modifiers` on the deployed host only when no one is typing. If a miss persists, capture physical input before changing another setting.
