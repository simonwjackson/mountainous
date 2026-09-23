# Kanata: hardware-level keyboard remapping below the compositor.
# Ports Corne home-row mods from simonwjackson/zmk-config.
# See docs/decisions/kanata.md for layer layout, timings, and device regrab architecture.
{
  nixos.modules.desktop = {
    config,
    lib,
    pkgs,
    ...
  }: {
    services.kanata = {
      enable = true;
      keyboards.all = {
        # Empty list: kanata finds and intercepts every keyboard itself.
        devices = [];
        extraDefCfg = ''
          process-unmapped-keys yes
          concurrent-tap-hold yes
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

            ;; Require prior idle for A/S/D layers and the control holds.
            ;; F has no such guard so CHK can open after fast typing.
            idle-slow 150

            ;; The Corne's hm_shift, used for both shift keys.
            t-shift 200

            ;; A 150ms hold lets GUI respond sooner after typing. An ordinary
            ;; space held this long can instead become GUI, lose the space,
            ;; and run a shortcut, including SUPER+C (close window).
            ;; Trial with normal typing before making it permanent.
            t-space 150

            ;; Simultaneous combo timeout.
            t-combo 150
          )

          (defalias
            a-dir (tap-hold-release $qt $t-pinky  a (layer-while-held dir) (require-prior-idle $idle-slow))
            s-num (tap-hold-release $qt $t-ring   s (layer-while-held num) (require-prior-idle $idle-slow))
            d-wrp (tap-hold-release $qt $t-middle d (layer-while-held wrp) (require-prior-idle $idle-slow))
            ;; Without an idle gate, an ordinary fast 'fl' can activate
            ;; CHK+L (Delete). Trial this trade-off before keeping it.
            f-chk (tap-hold-release $qt $t-index  f (layer-while-held chk))

            ;; Deliberately plain tap-hold, not the -press or -release
            ;; variants the letters use. Those resolve the hold EARLY when
            ;; another key is pressed, which is exactly what typing looks
            ;; like. Plain tap-hold only ever holds on timeout, so a letter
            ;; arriving before the term yields a space. A space held past
            ;; 150ms can become SUPER even during prose; keep the close-window
            ;; risk visible rather than calling the mapping harmless.
            spc-gui (tap-hold $qt $t-space spc lmet)

            ;; Shift and control on the bottom row, mirroring the Corne's
            ;; hm_shift and hm_pinky. Each hand gets one of each, so a
            ;; modifier is always available on the hand opposite the key it
            ;; modifies.
            ;;
            ;; The shifts have no prior-idle gate: a modifier must work when
            ;; the preceding key was just typed. The cost is that rolling
            ;; through physical C or M while typing v or m can turn that
            ;; letter into Shift. Controls keep their prior-idle gate because
            ;; Ctrl+W and Ctrl+C can destroy work.
            ;;
            ;; The physical C key taps v and holds shift. The physical Left
            ;; Shift key taps z and holds control. Both keep a modifier on
            ;; the bottom row while its letters sit one key to the right.
            ;; Physical / taps ' and holds control.
            c-sft    (tap-hold-release $qt $t-shift v lsft)
            m-sft    (tap-hold-release $qt $t-shift m rsft)
            apos-ctl (tap-hold-release $qt $t-pinky ' lctl (require-prior-idle $idle-slow))
            lsft-ctl (tap-hold-release $qt $t-pinky z lctl (require-prior-idle $idle-slow))

            ;; A keypress that reaches the system and means nothing. It retires
            ;; the arrow cluster and the four editing keys. See the notes at
            ;; their use sites for why this is not XX.
            dead f24
          )

          ;; Simultaneous key combos.
          ;; Pressing jk or kj quickly produces Enter.
          ;; Pressing kl or lk quickly produces Escape.
          ;; Combos are disabled on navigation and symbol layers so arrow
          ;; movement, brackets, and number typing are never interrupted.
          (defchordsv2
            (j k) (macro ret) $t-combo first-release (dir pag fun num sym wrp chk)
            (k l) (macro esc) $t-combo first-release (dir pag fun num sym wrp chk)
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

            ;; The bottom-row letters sit one key to the right of their
            ;; labels: the physical Z key types x and the physical X key
            ;; types c. The physical C key takes v and holds shift, and the
            ;; physical Left Shift key takes z and holds control. Every
            ;; letter on the row stays reachable.
            ;;
            ;; Extended bottom row mapping:
            ;; Physical V types comma (,).
            ;; Physical B is inert (@dead / f24).
            ;; Physical N types period (.).
            ;; Physical comma (,) types n.
            ;; Physical period (.) types b.
            ;; Physical slash (/) taps apostrophe (') and holds Left Ctrl.
            z x
            x c

            c @c-sft
            v ,
            b @dead
            n .
            m @m-sft
            , n
            . b
            / @apos-ctl

            ;; Left Shift taps z and holds Left Ctrl, which keeps Kamoi's
            ;; rule that Left Shift acts as Left Ctrl. Shift itself comes
            ;; from held C, held M, or the right Shift key.
            lsft @lsft-ctl

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

            ;; The four editing keys are dead on the same principle as the
            ;; arrow cluster: reaching for the key is the habit that stops the
            ;; chord or the layer from ever becoming automatic. Each function
            ;; keeps a channel, so nothing is lost:
            ;;
            ;;   Enter      press jk or kj
            ;;   Escape     press kl or lk
            ;;   Backspace  hold F, then h
            ;;   Tab        hold F, then j  (shift-tab is hold F, then k)
            ;;
            ;; The chords and the CHK layer emit from kanata's own virtual
            ;; keyboard, so this map never sees them and they still produce the
            ;; real keys. The one consequence is at boot: the greetd password
            ;; prompt takes Enter only from the jk chord.
            ;;
            ;; f24 and not XX, for the measured reason above.
            esc  @dead
            ret  @dead
            tab  @dead
            bspc @dead

            ;; Number row, punctuation, right shift, and function keys
            ;; are inert on the base layer to reinforce Corne layer discipline.
            ;; Numbers/symbols come from NUM, SYM, WRP; function keys from FUN.
            grv  @dead
            1    @dead
            2    @dead
            3    @dead
            4    @dead
            5    @dead
            6    @dead
            7    @dead
            8    @dead
            9    @dead
            0    @dead
            -    @dead
            =    @dead

            [    @dead
            ]    @dead
            \    @dead
            '    @dead
            rsft @dead

            f1   @dead
            f2   @dead
            f3   @dead
            f4   @dead
            f5   @dead
            f6   @dead
            f7   @dead
            f8   @dead
            f9   @dead
            f10  @dead
            f11  @dead
            f12  @dead
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

    systemd.services.kanata-all.serviceConfig = lib.mkIf config.services.kanata.enable {
      Restart = "always";
      RestartSec = "1";
    };

    # Kanata sometimes never grabs a keyboard that is plugged in while it is
    # running, and it never retries that device. Measured on hiyori against
    # kanata 1.12.0: a device on a path kanata had previously held was
    # ignored for 40s while alone, and grabbed immediately after a restart.
    # It is not a permission race; udev applies group 'input' in 13-56ms and
    # kanata already waits 200ms.
    #
    # Restarting on keyboard arrival is the blunt fix that makes "any
    # keyboard" true. It costs roughly two seconds of unmapped input at the
    # moment you attach a keyboard, which is the moment you are least likely
    # to be typing.
    services.udev.extraRules = lib.mkIf config.services.kanata.enable ''
      ACTION=="add", SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT_KEYBOARD}=="1", ATTRS{name}!="kanata", TAG+="systemd", ENV{SYSTEMD_WANTS}+="kanata-regrab.service"
    '';

    # try-restart, not restart: during boot the keyboards appear before
    # kanata starts, and try-restart is a no-op while it is inactive. That
    # turns what would be a restart per device at every boot into nothing.
    #
    # The sleep coalesces the burst a single USB keyboard produces, since one
    # keyboard usually registers several event nodes. oneshot means systemd
    # will not stack a second run while this one is still sleeping.
    systemd.services.kanata-regrab = lib.mkIf config.services.kanata.enable {
      description = "Restart kanata so a newly attached keyboard is grabbed";
      serviceConfig = {
        Type = "oneshot";
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 3";
        ExecStart = "${config.systemd.package}/bin/systemctl try-restart kanata-all.service";
      };
    };
  };
}
