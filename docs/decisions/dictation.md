# Dictation

## Purpose

Hold a key, speak, and release the key. The spoken words go into the focused
text field. This is a NixOS and Quickshell version of `davis7dotsh/sotto`, which
is a Mac application.

This document records settled decisions. It grows as the interview settles more
of them. It is not a design document and not a plan.

## Words

Use one word for each idea.

| Word | Meaning |
| --- | --- |
| Dictation | This feature, end to end. The repository already uses this word. |
| Take | One recording. It starts at key press and it ends at key release. |
| Talk key | The key that the user holds to make a take. |
| Backend | The service that turns audio into text. |
| Insertion | The step that puts the text into the focused field. |

The word "sotto" names the upstream Mac project only. Do not use it for this
feature.

## Settled decisions

### D1. The client lives on `cairn`

Build the client in the `cairn` worktree for its Quickshell desktop hosts.

The `cairn` tree holds the Quickshell desktop. The request asks for Quickshell.
The `unified` branch holds the older ironbar desktop, and ironbar cannot show
status for this tree.

Correction, recorded 2026-09-20: an earlier version of this decision said the
whole feature lives on `cairn`. That is wrong. `cairn` defines `hiyori`
and `tate` only. Zao is defined on `unified`. The server work cannot
land in `cairn`.

### D2. Zao runs Whisper

Zao is the speech-to-text machine. Zao is `x86_64-linux` and it has an NVIDIA
GPU, so it can run Whisper with useful speed.

Cost of this decision: dictation needs the network and it needs Zao to be
awake. A take fails when Zao is unreachable.

### D3. Build the thin slice first

The first version does four things: record a take, send it to a backend, get
text, and insert the text. A Quickshell surface shows the state.

Do not build shared settings, history, a dictionary, list formatting, or
proofreading yet. Each one is a separate decision.

### D4. The talk key holds

The user holds the talk key for the length of the take. The take ends at key
release.

This matches upstream. The existing `features/dictation` script toggles instead,
and that is not the behaviour we want.

A hold needs a key-release event from Hyprland. Kanata sits below the
compositor and it makes most keys inert on the base layer, so the talk key must
be a key that Kanata passes through or a key that Kanata emits on purpose.

### D4a. The talk key is Right Alt

The talk key is Right Alt (`ralt`).

Kanata does not map `ralt` on the base layer, so the key reaches Hyprland today.
Upstream uses Right Option, which is the same physical position.

Kanata also leaves Caps Lock, Right Ctrl, and Menu alone. Those stay free for
later use.

### D5. Groq stays as a backend

Keep the Groq Whisper API as a second backend. It works today. It gives a
reference result to measure the Zao backend against.

Cost of this decision: Groq is a third party. Audio that goes to Groq leaves the
tailnet. The backend choice must be visible to the user.

### D5a. Fallback to Groq is automatic and visible

When Zao does not answer, the take goes to Groq. The Quickshell surface shows
which backend ran the take.

Cost of this decision: a network fault moves your voice to a third party. The
user must be able to see this after the fact, so the backend name must stay on
screen with the result, not only during the take.

### D6. Insertion uses the PRIMARY selection

Write the text to the PRIMARY selection with `wl-copy --primary`. Then send
Shift and Insert with `wtype`.

This is the method the existing `features/dictation` script uses, and it works on
this Hyprland setup. The cost of the text does not grow with its length, and the
real clipboard does not change.

### D7. The Quickshell surface is an overlay and a bar state

A small overlay appears near the centre of the screen during a take. The top bar
also shows the state and the backend.

Meta and I hide the top bar and the dock together. The overlay stays visible in
that state, so the user always sees that a take is live.

### D9. The model is large-v3-turbo at half precision

Zao runs `large-v3-turbo` at half precision. The file is about 1.6 GB.

Zao has 6 GB of video memory and it also serves Sunshine with NVENC. This model
leaves more than 4 GB for the encoder.

### D10. The model stays loaded

The speech service holds the model in video memory at all times.

The first take of the day is then as fast as the tenth.

Cost of this decision: about 1.6 GB of video memory is not available to games or
to Sunshine.

### D11. The language is English

The backend gets `en`. It does not detect the language.

Detection costs time and it can choose wrong on a short take. The existing
`features/dictation` script already defaults to English.

### D12. Zao runs the whisper.cpp server

Zao runs `whisper-cpp` built with `cudaSupport`. The unit starts
`whisper-server` with `--inference-path /v1/audio/transcriptions`.

The route then matches the path Groq serves, and the reply shape already
matches. One client sends the same request to both backends. Only the URL and
the authorization header change.

The CUDA closure for `whisper-cpp` holds `cuda_cudart` and `libcublas`. The
Wyoming path needs cuDNN and a `ctranslate2` rebuild, which is much larger.

Cost of this decision: nixpkgs has no NixOS module for `whisper-cpp`. This repo
owns the systemd unit, the model file, and the state directory.

### D13. Send the take once, after release

The client records the take to a file. It sends the file when the user releases
the talk key.

Streaming the upload saves about 100 ms, because the audio is small. The GPU
time is the cost that matters.

The target is about 0.5 s from release to inserted text. Four levers hold that
target:

1. Trim the Whisper audio window for short takes.
2. Turn on flash attention.
3. Keep the tailnet path to Zao warm.
4. Show the overlay at key press, not at first result.

Cost of this decision: no words appear while the user speaks.

### D14. The recorder is pw-record

The client records with `pw-record`. PipeWire runs the audio on this desktop,
and `pw-record` speaks to it directly.

The older script uses `sox`, which reaches PipeWire through a compatibility
layer. This removes that layer.

### D15. A take is 0.25 s to 180 s

A take shorter than 0.25 s cancels. The client sends no request.

A take stops at 180 s.

The short gate stops a stray tap of Right Alt from making an empty request.
Both numbers match upstream.

### D16. Secrets use sops-nix

The Groq key lives in `secrets/fleet.yaml` and it is read through sops-nix.

The `cairn` tree uses sops-nix. The `unified` branch uses agenix and a
`/run/agenix/groq-env` path. Do not copy that path.

### D17. Quickshell owns the take

One Quickshell state machine owns a take from key press to inserted text.
Hyprland reports key down and key up and nothing more. Quickshell starts
`pw-record` and the upload as child processes.

One process holds the state, so no state files live in `/run` and two processes
cannot disagree.

Cost of this decision: the shell process now does network work. A fault in the
dictation code can affect the bars and the dock.

### D18. Measure the audio window, then fix it

Measure latency against accuracy on Zao with real takes. Then fix one
`--audio-ctx` value.

Do not guess the value. Do not vary it with take length, because quality that
changes with take length is hard to reason about later.

### D19. The overlay shows state only

The overlay shows the state of the take: recording, working, done, failed. It
does not show a level meter and it does not show the text.

### D20. Transport uses the Zao tsnet-proxy pattern

`whisper-server` binds to `127.0.0.1` on Zao. The service reaches the tailnet
through `mountainous.features.tsnet-proxy.services`, which gives it its own
tsnet node and its own tailnet hostname over HTTPS.

This is the pattern every other Zao service uses. Jellyfin uses it with
`hostname = "watch"`.

### D21. Always paste, and keep a clipboard copy

The client always sends Shift and Insert after a take. It also puts the text in
the real clipboard.

Wayland gives no reliable way to know whether the focused surface holds a text
cursor. A check based on `zwp_input_method_v2` reports "no text box" for every
XWayland window and for Chromium without `--enable-wayland-ime`. The web apps
run Chromium, so the check would fail where the user dictates most.

The clipboard copy means a failed paste costs one Ctrl+V, not one lost take.

Cost of this decision: in a game or an image viewer, Shift and Insert can
trigger an action in that program.

### D22. The server lands on `unified`, the client on `cairn`

The Zao whisper service and its tsnet-proxy entry land on `unified`, because
`unified` defines Zao. The Quickshell client lands on `cairn`, because `cairn`
defines Hiyori and holds the shell.

Cost of this decision: the feature has two commits in two trees and two deploy
steps. No single commit holds the whole feature.

### D23. The tailnet hostname is `dictate`

The service is reachable at `https://dictate` on the tailnet. The client calls
`https://dictate/v1/audio/transcriptions`.

The name states the job, not the engine, so the name survives an engine change.

### D24. The model is a flake input

The `ggml-large-v3-turbo` file enters the tree as a flake input with
`flake = false`, pinned by hash. `nix flake update` moves it.

This follows the repo rule in `AGENTS.md`, which prefers a flake input over
`fetchurl` or `fetchFromGitHub`.

Cost of this decision: 1.6 GB enters the Nix store and the lock file.

### D25. Takes queue

A press of the talk key during a working take starts a new take. The takes run
in order.

Cost of this decision: text can arrive after the user moves to another window.
The design must guard the destination, because an unguarded queue types the last
sentence into the wrong program.

### D26. Delete audio on success, keep it after a failure

The client deletes the audio file when a take succeeds. It keeps the last failed
take for one retry.

The file lives under `/run`, which is memory and clears at reboot.

### D27. Testing is manual

No probe script and no VM test.

This conflicts with the repo rule in `AGENTS.md`, which says to run tests before
completing a task. The rule is set aside here by an explicit decision, recorded
on 2026-09-20. Revisit it when the feature stops changing.

### D28. Cancel uses the `k` and `l` chord

While a take runs, the `k` and `l` chord cancels it. That chord is the real
Escape on this keyboard.

Cancel is consistent with Escape everywhere else here.

Cost of this decision: the user holds the talk key and presses two more keys.

### D29. A finished take pastes into whatever window has focus

The client does not compare the focused window at key press with the focused
window at insertion. It pastes into the window that has focus when the text
arrives.

Cost of this decision: a queued take can type a sentence into a chat window, a
terminal, or a game, if the user switches windows while the take works. The
clipboard copy from D21 does not undo that.

### D30. The queue has no limit

Any number of takes can wait.

Cost of this decision: a stalled backend collects takes. When it recovers, every
stale sentence pastes in order into the window that has focus then. D29 and D30
together make this the largest known risk in the design.

### D31. Configuration is Nix module options

Backend URLs and their order are options on the module, set per host. They are
not a runtime file.

The `cairn` tree declares options as `options.mountainous.<name>` inside a layer
module. `modules/printing.nix` is the pattern to copy.

### D32. The top bar shows dictation only when it matters

The top bar shows a dictation state during a take, and after a failure until the
user dismisses it. It shows nothing at other times.

The bar competes for space with the clock, the battery, and the network.

### D33. Fall back after three seconds

The client gives Zao three seconds to answer. After that it sends the take to
Groq.

Cost of this decision: a slow but working Zao can lose a take to Groq.

### D34. Record from the PipeWire default source

The client records from whatever PipeWire calls the default source.

A connected headset becomes the default source, so the feature follows it with
no list to maintain.

Cost of this decision: it also follows a device the user did not mean to use.

### D35. Paste the text with the white space trimmed

The client trims white space at both ends of the returned text. It changes
nothing else. It does not add a trailing space and it does not remove the final
full stop.

### D36. Shift with the talk key sends Enter

Hold Shift with the talk key, and the client presses Enter after the paste.

This is the `--return` flag from the old script, on a modifier instead of a
second command.

### D37. No take while the session is locked

The talk key does nothing while the session is locked. The client starts no
recording.

A lock screen holds a password field. A take that pasted into it would type
speech into that field, and the Enter modifier from D36 would submit it.

### D38. Never log the text

The client logs state changes and errors. It never writes the transcript to the
journal.

The old script logs every transcript to a file. Do not copy that.

Cost of this decision: a wrong transcript cannot be studied after the fact.

### D39. The model keeps its memory during a game stream

Nothing stops the speech service when Sunshine has a session.

1.6 GB of 6 GB leaves room for most games at 1080p.

Cost of this decision: a heavy game can run out of video memory. That failure
will look like a game problem, not a dictation problem. Check the speech service
first when a game reports a memory fault on Zao.

### D40. The overlay sits at the bottom centre

The overlay appears at the bottom centre of the focused screen, above the dock.

It stays clear of text the user edits, and it stays visible when Meta and I hide
the bar and the dock.

Cost of this decision: it sits near the dock, so the two can read as one thing.
The visual design must separate them.

## Measured facts

These facts come from the pinned nixpkgs revision `b1b87598`.

- `whisper-cpp` 1.9.2 exists. It accepts `cudaSupport`. It installs
  `whisper-server`. It has no NixOS module.
- `whisper-server` serves `POST /inference` by default. The flag
  `--inference-path` renames that route, so it can match the OpenAI path that
  Groq uses. The reply is `{"text": "..."}`, which is the same shape Groq
  returns.
- `services.wyoming.faster-whisper` exists and accepts `model = "turbo"` and
  `device = "cuda"`. The `device` option defaults to `cpu`. CUDA needs an
  override of `ctranslate2` with `withCUDA`, which also pulls cuDNN.
- Whisper pads every take to a 30 second window. A 3 second take costs nearly
  the same GPU time as a 25 second take. The `--audio-ctx` flag trims that
  window.
- A 10 second take is about 320 kB at 16 kHz mono. The upload is not the slow
  part on the tailnet.
- `cairn` defines the hosts `hiyori` and `tate`. `unified` defines
  `aka`, `aso`, `fuji`, `ibuki`, `kita`, `rakku`, `sobo`, `usu`,
  `yari`, `yuki`, and `zao`.
- `cairn` uses sops-nix. `unified` uses agenix.
- Wayland has no query for "the focused surface has a text cursor". The nearest
  protocol is `zwp_input_method_v2`, which reports when a focused surface
  activates a text input. XWayland windows never do this. Chromium does it only
  with `--enable-wayland-ime`. The web apps in `modules/web-apps.nix` run
  Chromium with `--ozone-platform=wayland` and without that flag.
- The Hyprland Lua keybind object accepts `release`, `non_consuming`,
  `ignore_mods`, `long_press`, and `locked`. A press bind and a release bind
  together give hold behaviour. Source: `src/config/lua/objects/LuaKeybind.cpp`.
- `tests/` holds probe scripts only. There is no `nixosTest` and there are no
  flake checks in the `cairn` tree.
- Kanata maps the physical Escape key to `f24` on the base layer. Hyprland never
  receives an Escape key press from that key. Real Escape comes only from the
  `k` and `l` chord, which Kanata emits from its own virtual keyboard.
- Kanata also maps the arrow cluster, Enter, Tab, Backspace, the number row, the
  brackets, Right Shift, and F1 to F12 to `f24`. Many physical keys therefore
  produce the same `f24` press.

## Open questions

The interview continues. The backend design, the upload method, the recorder,
the take length limits, and the transport are not settled.

## Known risks

1. D29 and D30 together. An unlimited queue that pastes into the current window
   can type stale sentences into the wrong program. The user accepted this cost
   on 2026-09-20 after it was stated twice.
2. D27. No automatic test covers this feature.
