# Terminal fonts and Ghostty reload

Built for both themes. Myoko verification and deployment belong to the parent.
This supersedes the terminal-font and single-instance reload limits in the native
phase 3 section. UI and tab-bar fonts, colours and padding are unchanged.

## Terminal faces

| Theme | Terminal face | Licence and locked source | Nominal target at scale 1.5 |
|---|---|---|---|
| Windows 98 | Fixedsys Excelsior | Public domain / CC0; `kika/fixedsys`, `3f37fa8855bdbc542c817947ede82bef7c4049eb` | 16 pt → 32 device px em; 16 px cell; each source pixel is 2 device px |
| Platinum | ProFontIIx Grid | MIT; Tobias Jung's `profontiix.zip`, flake-locked by content hash | 13.5 pt → 27 device px em; 18 px cell; each source pixel is 3 device px |

ProFont originated as a Macintosh programming face, in the Monaco role. It is
not Apple's Monaco. Its small Macintosh bitmap strike is a closer fit than its
smoothed scalable outlines. `terminal-fonts.py` converts the supplied 9 ppem
strike to square outlines. No glyph is invented or copied from Apple fonts.
The derivative has a new family name and retains the upstream MIT notice.
Fixedsys already has square outlines. Its upstream format-4 cmap incorrectly
includes non-BMP characters; the build removes those invalid entries while
keeping their valid format-12 mappings. The source README carries the public
domain/CC0 statement. Both sources are non-flake inputs, not vendored fonts.

Both faces have real grid-bold derivatives: a second horizontal device-pixel
strike at the selected size, clipped at the existing advance. This keeps the
small counters open, unlike a whole source-pixel strike. Bold does not enlarge the terminal
cell. Synthetic bold/italic is disabled, because FreeType's fractional
emboldening would break the grid. The cost is that italic uses the upright
face. No extra letter spacing or cell-width adjustment is applied.

The installed-font check asserts equal ASCII advances, non-empty glyphs,
whole-grid regular/bold outlines and unchanged bold advances. The regular
faces have 6,192 and 261 mapped codepoints respectively. `DejaVu Sans Mono`
is an explicit Unicode fallback; the existing Noto installation supplies CJK
and emoji through fontconfig. Box and block drawing use Ghostty's internal
cell-fitting renderer. Nerd PUA ranges are explicitly mapped to the installed
`Symbols Nerd Font Mono`, so Fixedsys's private mappings cannot displace prompt
icons. The repository does not configure a Starship, Powerline or other custom
shell prompt. The capture shows the actual Bash prompt, plus explicit Nerd
icons used by common prompts/tools. The fallback check reads the installed
Unicode and icon cmaps, not just package names.

W95FA Grid and ChicagoFLF remain the desktop UI and tab fonts. The writable
`ghostty/mountainous.conf` still comes from the native generator and the
Hjem-delivered root still includes it. The terminal family list is reset before
the primary and fallback faces, so reloads cannot accumulate old families.
These two sizes target the existing scale 1.5. Other output/text scales can
produce non-integer source pixels; they have not been claimed as grid-exact.

The grid assertions above are font-space and nominal-transform checks, not
proof of sharp GTK pixels. Pixel sampling of the real nested screenshots finds
greyscale edge pixels at scale 1.5. Thus **perfectly sharp fractional-scale
rendering is not verified**; the spacing fix and equal font advances are
verified. GTK's integer backing buffer and compositor resampling are a possible
cause, not a measured diagnosis. No Ghostty/GTK renderer patch is included.

## Ghostty live switching

The previous call addressed only `com.mitchellh.ghostty`. Real nested Ghostty
reproduces the failure: rewriting the Platinum include and calling that action
changes the default application, but leaves a non-single-instance terminal and
`io.github.simonwjackson.mountainous.term` on Win98. The custom terminal keeps
its old geometry and colours. The old proportional face also leaves btop below
its minimum 80 columns in the same window.

The packaged desktop entry runs `ghostty --gtk-single-instance=true` and
advertises `com.mitchellh.ghostty`; Super+N runs plain `ghostty`. Super+T uses
the custom class above and `-e herdr`, not a separate desktop entry.

The important upstream detail is that **`-e` forces NON_UNIQUE**, even after
`--gtk-single-instance=true`. This is how Super+T launches herdr. NON_UNIQUE
applications export their GTK actions on a unique D-Bus connection, but do not
own a well-known application name. A custom class also changes the object path.

`reload-ghostty.py` lists unique connections on the current session bus, asks
D-Bus for each owner PID, and checks that owner's executable is Ghostty. It
introspects only those connections and invokes `reload-config` on their actual
`org.gtk.Actions` paths. It does not scan process names, guess custom IDs,
activate an absent application, send a signal/key, create a window or focus one.
One disappearing terminal does not block the others; errors are reported.
The existing switcher owns state, file publication and when reload runs.
The additional Python GObject binding is a runtime dependency.

`checks.ghostty-reload` runs five real GApplications on a private bus: the
well-known default, two NON_UNIQUE instances, the production custom ID and a
second arbitrary ID. All five receive the action; an unrelated application
does not. An empty bus starts nothing. The native check retains its installed
activation-service sentinel too.

## Evidence and checks

Evidence root: `/tmp/tandem/terminal-fixes/` (served under
`http://100.114.19.92:8765/tandem/terminal-fixes/`). The nested capture uses real
Ghostty 1.3.1 and btop 1.4.7, not a terminal imitation. It runs at 2880×1800,
scale 1.5. The same three terminal PIDs remain through both directions and all
five appearances; focus addresses stay equal before and after each switch.
The custom-class and ordinary NON_UNIQUE shells change cell geometry live.

| Appearance | Screenshot (btop, Bash prompt, `ls -la`, bold, boxes, blocks and icons) |
|---|---|
| Win98 light | `session/shots/win98-light.png` |
| Win98 dark grey | `session/shots/win98-dark.png` |
| Platinum light | `session/shots/platinum-light.png` |
| Platinum dark grey | `session/shots/platinum-dark.png` |
| Platinum extra black | `session/shots/platinum-extra.png` |

`before-win98-dark.png` and `before-switch-platinum.png` reproduce the old
proportional font and old single-name reload code in the isolated session.
They are not a claim that the old packaged command was rerun: that historical
store path had been garbage-collected. The harness writes the previous font
settings and runs the previous exact D-Bus call.

Focused checks: `terminal-fonts`, `ghostty-reload`, `native-themes`,
`desktop-theme` and `desktop-theme-shell`. Native themes also exercises the delivered
root include, all five Ghostty config validators, palette agreement and the
unchanged GTK/Qt UI fonts. Python Ruff/compilation, ShellCheck, Lua parsing,
Nix formatting for the changed font/theme modules and whitespace checks are
run separately. No full flake check or full test suite runs here.

The capture is behind `/tmp/phase1/heavy.sh`. Bubblewrap exposes only
`/dev/dri/renderD128`, not a card node or real input; `AQ_DRM_DEVICES` and
`SEATD_SOCK` point to nonexistent paths. Device-fd scans, compositor logs and
cleanup scans are in `session/logs/`. The harness traps exit and stops all its
processes. Nothing connects to the real session's compositor or changes its
appearance. Nix checks run through the Unzen/federation wrapper.

Not verified: Myoko's GPU and real input, herdr's live server,
other display/text scales, X11 and sandboxed/Flatpak Ghostty. The parent verifies the existing Super+T terminal after deployment.

## Duplicate external outputs and unplug cleanup (follow-up)

`hyprland.lua` attaches `duplicate-outputs.lua`. It mirrors later matching
external connectors onto the first by connector-name order, comparing non-empty
description, current width/height and refresh rate (0.01 Hz tolerance).
**eDP-1 is excluded from both sides.**

Mirroring is safer than disabling: whichever connector the hub physically wires
to its panel still has a picture. A mirror is not a workspace destination.
Cost: genuinely separate panels with identical descriptions and modes will also
mirror. This rule trusts descriptions; it does not prove physical identity.

Added/removed/layout-changed events defer and coalesce reconciliation. Active
sources expose their mirror sinks; stale rules owned by this module are cleared
on unplug or mode changes. Other manual mirrors are left alone. Hyprland
promotes a remaining mirror when its source leaves. No state file is added.
`checks.duplicate-outputs` tests order, three duplicates, source unplug, different
modes/descriptions, blank descriptions and eDP-1 protection.

Both themes use one filtered screen list for Desktop creation, primary-screen
fallback and popup routing. In Hyprland it intersects Qt screens with active
workspace destinations, excluding mirror/disabled sinks. Non-Hyprland previews
retain their own screen lists. The same check tests this JS policy.

### Existing ordinary-unplug bug, reproduced on cairn

The unmodified cairn `7512e313` root and unchanged `ThemeDesktop.qml` ran in the
nested compositor, with only an observation IPC added to the private staged
copy. After adding and removing a normal, unmirrored `CAIRN-UNPLUG` output,
`Quickshell.screens` dropped it, but `root.desktops` retained its name. This is
an **existing ordinary-output unplug bug**, not a duplicate-policy regression.
Evidence: `session/logs/cairn-normal-{connected,unplugged}.json`.

`ThemeDesktop.onDesktopChanged` is not a reliable delegate teardown signal.
The Variants delegate now unregisters in `Component.onDestruction`, retaining
its registration name and Desktop identity. Both teardown and theme-change
cleanup compare identity before deletion, so an old delegate cannot remove a
newer registration under the same name. No dead QScreen reference is retained.

The real follow-up capture passes source unplug, remaining-output promotion and
ordinary output removal. Its registry contains exactly:

| State | Screens and Desktop registrations |
|---|---|
| Mirrored | `eDP-1`, `DUP-A` |
| Source removed | `eDP-1`, `DUP-B` |
| Remaining output removed | `eDP-1` |

The identity probe passes and leaves no entry. It is injected only into the
private capture copy; **no `identity-probe` entry or test IPC ships**.
`duplicate-followup-runtime.log` records both the cairn reproduction and the
passing current behavior. `session/logs/registration-identity.txt` and the three
`*-desktops.json` files record the results. Quickshell has no TypeError or
ReferenceError; compositor config errors are empty. Device scans find zero
card nodes; cleanup reports **processes left: 0**.

The nested headless backend supplies empty descriptions and exposes no setter.
Identical non-empty descriptions are therefore unit-tested, while the real
compositor and Quickshell exercise the chosen mirror and hot-plug mechanism.
Myoko's hub/EDID, GPU and real input still need the parent's verification.
Before rebasing, the symlink staging form of QML lint passed with 64
known-idiom warnings, versus 59 on cairn. After rebasing onto `59d68d31`,
full-copy staging reports the same 22 missing-member warnings as that baseline
(`MenuState`, `ThemePicker`, `GlanceState`, `ThemeSounds`), with **zero added
type warnings**. Raw-tree lint has the same singleton-resolution limitation.
Real Quickshell runs the changed lifecycle without TypeError or ReferenceError.
