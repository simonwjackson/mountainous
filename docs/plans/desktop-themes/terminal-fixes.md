# Terminal fonts and Ghostty reload

Built for both themes. Myoko verification and deployment belong to the parent.
This supersedes the terminal-font limit in the native phase 3 section.
Every-instance Ghostty reload follows in a separate commit. UI and tab-bar fonts, colours and padding are unchanged.

## Terminal faces

| Theme | Terminal face | Licence and locked source | Size at scale 1.5 |
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

