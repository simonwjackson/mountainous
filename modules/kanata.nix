# Kanata: hardware-level keyboard remapping below the compositor.
#
# This is a port of the left home row from simonwjackson/zmk-config, so the
# Corne and this laptop answer to the same fingers:
#
#   hold A -> DIR    arrows, and the way into PAG and FUN
#   hold S -> NUM    a numpad under the right hand, and the way into SYM
#   hold D -> WRP    bracket pairs, open and close side by side
#   hold F -> CHK    backspace, tab, shift-tab, delete
#   G       -> plain, exactly as on the Corne
#
# Left Alt and Left Meta are also swapped, which puts Hyprland's SUPER binds
# on the key beside the spacebar.
#
# Remapping lives here rather than in Hyprland because timed hold layers and
# key interception belong at the evdev/uinput layer, before keys reach Wayland.
#
# Three things about the port that are decisions, not transcription:
#
#   * Timings are per finger, copied from the Corne rather than flattened.
#     ZMK's flavor = "balanced" means the hold wins early when another key is
#     pressed AND released, which is exactly kanata's tap-hold-release.
#     quick-tap-ms is kanata's tap-repress timeout, and require-prior-idle-ms
#     has a direct equivalent.
#
#   * Rows 1 and 2 are identical between the Corne and a US laptop, so they
#     port by letter. Row 3 is not: the Corne carries ", " on the left and "B"
#     on the right. Row 3 therefore ports by POSITION, because a numpad whose
#     1-2-3 are not adjacent is not a numpad. So Corne "M N B" becomes the
#     laptop's "m , ." under the same three fingers.
#
#   * The Corne's KP_PLUS and KP_MULTIPLY are keypad codes, which need numlock
#     to produce a character. The shifted main-row forms produce "+" and "*"
#     unconditionally, so those are used instead.
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
          # Empty list: kanata finds and intercepts every keyboard itself.
          devices = [ ];
          extraDefCfg = ''
            process-unmapped-keys yes
          '';
          config = ''
            ;; deflayermap maps only what a layer changes; everything else is
            ;; transparent and falls through. That keeps eight layers readable
            ;; and matches ZMK's &trans exactly.
            (defsrc)

            (defvar
              ;; quick-tap-ms, shared by every hold-tap in the Corne config.
              qt 175

              ;; tapping-term-ms, weakest finger to strongest.
              t-pinky  280
              t-ring   250
              t-middle 230
              t-index  200

              ;; require-prior-idle-ms. The index finger is trusted sooner.
              idle-slow 150
              idle-fast 125

              ;; The Corne's hm_shift, used for both shift keys.
              t-shift    200
              idle-shift 125

              ;; Space is the one key that must never misfire, so it gets its
              ;; own numbers rather than borrowing a finger's.
              ;;
              ;; A wrong hold here does not merely swallow a space: SUPER+C
              ;; closes the focused window in this Hyprland config, so a
              ;; misfire can destroy work. The guards are deliberately blunt.
              ;;
              ;; Two independent guards, and a misfire needs BOTH to fail.
              ;;
              ;; idle-space: space may only hold if no key was pressed in the
              ;; preceding window. Space almost always lands a few tens of
              ;; milliseconds after the letter ending a word, so this alone
              ;; rules out virtually every space typed in prose.
              ;;
              ;; t-space: how long space must then be held. Measured on ridge,
              ;; prose was clean at 250ms until each key was held a full 250ms,
              ;; at which point space reached its own term and fired SUPER.
              ;; A heavy hand on the spacebar is real, so the term is set well
              ;; beyond any natural press. It costs a deliberate pause before
              ;; SUPER, which is the trade this key is worth.
              t-space    400
              idle-space 300
            )

            (defalias
              a-dir (tap-hold-release $qt $t-pinky  a (layer-while-held dir) (require-prior-idle $idle-slow))
              s-num (tap-hold-release $qt $t-ring   s (layer-while-held num) (require-prior-idle $idle-slow))
              d-wrp (tap-hold-release $qt $t-middle d (layer-while-held wrp) (require-prior-idle $idle-slow))
              f-chk (tap-hold-release $qt $t-index  f (layer-while-held chk) (require-prior-idle $idle-fast))

              ;; Deliberately plain tap-hold, not the -press or -release
              ;; variants the letters use. Those resolve the hold EARLY when
              ;; another key is pressed, which is exactly what typing looks
              ;; like. Plain tap-hold only ever holds on timeout, so a letter
              ;; arriving before the term always yields a space. The cost is
              ;; that SUPER needs space held first, then the letter; the gain
              ;; is that no roll can ever produce SUPER.
              spc-gui (tap-hold $qt $t-space spc lmet (require-prior-idle $idle-space))

              ;; Shift and control on the bottom row, mirroring the Corne's
              ;; hm_shift and hm_pinky. Each hand gets one of each, so a
              ;; modifier is always available on the hand opposite the key it
              ;; modifies.
              ;;
              ;; A wrong shift only capitalises a letter. A wrong control is
              ;; worse, since Ctrl+W and Ctrl+C destroy work, so the slash
              ;; takes the pinky's slower 280ms term rather than the 200ms
              ;; the shifts use.
              c-sft  (tap-hold-release $qt $t-shift c lsft (require-prior-idle $idle-shift))
              m-sft  (tap-hold-release $qt $t-shift m rsft (require-prior-idle $idle-shift))
              sl-ctl (tap-hold-release $qt $t-pinky / lctl (require-prior-idle $idle-slow))

              ;; A keypress that reaches the system and means nothing, used to
              ;; retire the arrow cluster. See the note at its use site for
              ;; why this is not XX.
              dead f24
            )

            (deflayermap (base)
              a @a-dir
              s @s-num
              d @d-wrp
              f @f-chk

              ;; Swap the left thumb modifiers. Every layer below inherits
              ;; this by falling through, so it holds while a layer is active.
              lalt lmet
              lmet lalt

              ;; Held space is the same SUPER that physical Left Alt emits.
              spc @spc-gui

              c @c-sft
              m @m-sft
              / @sl-ctl

              ;; Left Shift becomes control outright, which is Kamoi's own
              ;; rule: "use Left Shift as Left Ctrl". No tap-hold here, because
              ;; a tap of Shift produces nothing to preserve. Shift itself now
              ;; comes from held C, held M, or the right Shift key.
              lsft lctl

              ;; The arrow cluster is dead on purpose. Reaching for it is the
              ;; habit that stops hold-A from ever becoming automatic, and a
              ;; half-learned layer is worse than none.
              ;;
              ;; This does not affect DIR. Kanata writes its output to its own
              ;; virtual keyboard and never feeds that back through this map,
              ;; so hold-A + H still emits a real Left.
              ;;
              ;; f24 rather than XX, and that is not a style choice. Measured
              ;; on kanata 1.12.0: pressing a key mapped to XX breaks the very
              ;; next tap-hold, which resolves as a tap instead of a hold. It
              ;; is one-shot and time-independent, still broken after eight
              ;; seconds idle and fine on the attempt after. That turns the
              ;; exact habit this mapping exists to break -- reach for the
              ;; arrows, get nothing, fall back to hold-A -- into a failure
              ;; every single time. f24 is the inert key kanata's own docs use
              ;; as a no-op, and nothing in this system binds it.
              left @dead
              down @dead
              up   @dead
              rght @dead
            )

            ;; --------------------------------------------------------------
            ;; DIR, held with the left pinky on A.
            ;; The Corne also parks bluetooth pairing on the top row here.
            ;; That is radio management for a split keyboard and means nothing
            ;; on a laptop, so it is deliberately not ported.
            ;; --------------------------------------------------------------
            (deflayermap (dir)
              h left
              j down
              k up
              l rght
              ; =

              s (layer-while-held pag)
              f (layer-while-held fun)
            )

            (deflayermap (pag)
              h home
              j pgdn
              k pgup
              l end
            )

            (deflayermap (fun)
              y f1  u f2   i f3   o f4  p f5
              h f6  j f7   k f8   l f9  ; f10
              m f11 , f12
            )

            ;; --------------------------------------------------------------
            ;; NUM, held with the left ring finger on S.
            ;; --------------------------------------------------------------
            (deflayermap (num)
              y S-3  u 7  i 8  o 9  p S-5
              h S-=  j 4  k 5  l 6  ; -
              n S-8  m 1  , 2  . 3

              d (layer-while-held sym)

              ;; The Corne puts zero on the right thumb, opposite the holding
              ;; hand. Space is that thumb here.
              spc 0
            )

            (deflayermap (sym)
              y S-grv  u /     i S-\   o \  p grv
              h S-6    j S-2   k S-7   l S-4
              m S-/    , S-1
            )

            ;; --------------------------------------------------------------
            ;; WRP, held with the left middle finger on D.
            ;;
            ;; Each pair sits open-then-close on two adjacent keys, stacked
            ;; down the index and middle columns, per corne.keymap.backup:
            ;;
            ;;     u i   ->  [ ]
            ;;     j k   ->  ( )
            ;;     m ,   ->  { }
            ;;
            ;; The Corne puts < > on two right thumb keys. Space and the key
            ;; to its right are the laptop's right thumb, so the pair stays on
            ;; the thumb rather than moving up into the letters.
            ;; --------------------------------------------------------------
            (deflayermap (wrp)
              u   [    i ]
              j   S-9  k S-0
              m   S-[  , S-]
              spc S-,  ralt S-.
            )

            ;; --------------------------------------------------------------
            ;; CHK, held with the left index finger on F.
            ;; --------------------------------------------------------------
            (deflayermap (chk)
              h bspc
              j tab
              k S-tab
              l del
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
