# Original UI sounds

`generate.py` is the source for every WAV in
`../quickshell/themes/{platinum,win98}/sounds/`.

Author: mountainous contributors, 2026. Code and generated recordings:
**CC0-1.0**, <https://creativecommons.org/publicdomain/zero/1.0/>.
To the extent possible under law, the authors waive all copyright and related
rights in this code and these recordings. No warranty.

These are newly composed short electronic gestures, not Apple or Microsoft
recordings, samples, melodies or transcriptions. The theme names describe their
intended context, not their origin. No external sound source is used.

Rebuild: `python3 modules/desktop-sounds/generate.py modules/quickshell/themes`.
48 kHz mono signed 16-bit PCM. A 1.5 ms attack avoids hard sample edges. The
longest sound is 220 ms; the menu gestures are 12–18 ms. No leading silence.

The registry maps semantic shell events to recordings. `beep`, `critical` and
`emptyTrash` are available for future callers; there is no shell trash action
today. Do not invent a trash event or duplicate a notification to demonstrate it.
