# Original boot art

`generate.py` and `theme.script`: mountainous contributors, 2026,
**CC0-1.0**, <https://creativecommons.org/publicdomain/zero/1.0/>.
The generated PNGs have the same dedication. To the extent possible under law,
the authors waive all copyright and related rights in this code and art.
No warranty.

The art reuses our existing light desktop frame, colours and original lock
screen's two-face peak motif. It contains no Apple logo, Happy Mac, Microsoft
logo, Windows flag, screenshot or sampled third-party startup art.

Fonts are existing flake inputs: ChicagoFLF 2.1 (Public Domain) and the renamed
W95FA Grid derivative (SIL OFL 1.1). `modules/fonts.nix` installs their notices.
Plymouth's live password text uses its upstream DejaVu Sans default so the
initrd can display arbitrary device names; do not substitute a limited retro
font for password prompts.

Chicago95 was reviewed at the revision in `flake.lock`. Its README says
GPL-3.0+/MIT, but `Plymouth/Chicago95/win95_boot_0.png` visibly contains the
Microsoft word mark, Windows 95 logo and flag. No separate permission for those
assets is supplied. Its script also references missing `bullet.png` and
`SpriteNew()`. We do not treat the project's code licence as permission to ship
that Microsoft art. Neither that Plymouth art nor its script is copied into
this repository or the generated packages. The Win98 package uses our own
frame and peak instead. Simon/design review can replace this original art.
