# Prompt: Install Korri generic Sway game stream runner on aka

You are working in `/home/simonwjackson/code/github/simonwjackson/mountainous`.

Goal: configure the NixOS host `aka` to run Korri's generic Sunshine/Moonlight stream runner with **Sway as the compositor/session layer**.

## Target outcome

- `aka` runs a Sway session for the streaming workflow.
- `aka` does not enable or use Hyprland for this workflow.
- Sunshine exposes one generic app named `Korri Stream`.
- Sunshine does not know which game, launcher, browser, ROM, Steam URL, or app is launched.
- A trusted local launch intent selects what the generic Korri runner spawns.
- Korri's Sway repair path is enabled so the runner can use `swaymsg`/`SWAYSOCK` to repair fullscreen state.

## Korri input

Use the local Korri checkout as the flake input:

```nix
korri = {
  url = "path:/home/simonwjackson/code/sandbox/korri";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Korri exports:

- NixOS module: `inputs.korri.nixosModules.korri-game-stream`
- package/app: `korri-game-stream-runner`
- installed commands:
  - `korri-game-stream-runner`
  - `korri-game-stream-enqueue`

## Architecture to implement

1. A trusted local controller writes a launch intent containing a structured `LaunchSpec`.
2. Moonlight starts the generic Sunshine app `Korri Stream`.
3. Sunshine runs the Korri runner as its foreground command.
4. The runner consumes the pending launch intent and spawns that process.
5. The runner supervises lifecycle using one of:
   - foreground process exit,
   - `--lifecycle session`,
   - `--wait-json` monitor command.

Do not create one Sunshine app per game. Do not configure Sunshine with game-specific commands.

## Implementation steps

### 1. Add Korri to `flake.nix`

Add the `korri` input shown above.

Then import the Korri NixOS module for `aka`:

```nix
aka = mkHost {
  system = "x86_64-linux";
  hostPath = ./hosts/aka;
  extraModules = [
    inputs.korri.nixosModules.korri-game-stream
  ];
};
```

If `extraModules` already exists, append this module to the existing list.

### 2. Configure aka for Sway

Configure aka so Sway is the active compositor/session layer.

Required outcome:

```nix
programs.sway = {
  enable = true;
  xwayland.enable = true;
};
```

Configure the login/session path to start Sway for `simonwjackson`. Use the repo's established greetd/session conventions. A valid shape is:

```nix
services.greetd = {
  enable = true;
  settings = {
    default_session = {
      command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd sway";
      user = "greeter";
    };
    initial_session = {
      command = "sway";
      user = "simonwjackson";
    };
  };
};
```

Enable Wayland portals for Sway:

```nix
xdg.portal = {
  enable = true;
  wlr.enable = true;
  extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
};
```

Ensure Hyprland is not enabled for aka:

```nix
mountainous.features.hyprland.enable = false;
programs.hyprland.enable = false;
```

Use the exact option paths that evaluate cleanly in this repo. If a preset would enable Hyprland by default, override it for aka or avoid that preset and add the needed desktop/session pieces explicitly.

### 3. Configure Sway session environment export

The Korri runner needs a trusted file with fresh Sway session values:

- `XDG_RUNTIME_DIR`
- `WAYLAND_DISPLAY`
- `SWAYSOCK`

Target file:

```nix
services.korri.gameStream.sessionEnvFile = "/run/user/1000/korri-game-stream/session.env";
```

Arrange for the Sway session to write this at startup:

```bash
mkdir -p -m 700 /run/user/1000/korri-game-stream
chmod 700 /run/user/1000/korri-game-stream
cat > /run/user/1000/korri-game-stream/session.env <<EOF
XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR
WAYLAND_DISPLAY=$WAYLAND_DISPLAY
SWAYSOCK=$SWAYSOCK
EOF
chmod 600 /run/user/1000/korri-game-stream/session.env
```

Prefer deriving the runtime directory from the session environment when possible. If using `/run/user/1000`, verify `simonwjackson` is UID 1000 on aka.

### 4. Configure Sunshine generically

Configure Sunshine without Hyprland prep commands and without game-specific app commands:

```nix
services.sunshine = {
  enable = true;
  openFirewall = true;
  autoStart = true;

  settings = {
    output_name = 0;
    key_rightalt_to_key_win = "enabled";
  };
};
```

Adjust `output_name` after checking Sunshine logs if needed.

### 5. Enable Korri game stream

Add top-level Korri stream config:

```nix
services.korri.gameStream = {
  enable = true;

  appName = "Korri Stream";

  intentPath = "/run/user/1000/korri-game-stream/next-launch.json";
  intentMaxAgeSeconds = 300;

  gamescope.enable = true;

  sway.repair = true;
  sessionEnvFile = "/run/user/1000/korri-game-stream/session.env";
};
```

The launched process comes only from the pending launch intent.

## Validation before switching

From the Mountainous repo root:

```bash
nixos-rebuild build --flake .#aka
```

Also evaluate key config:

```bash
nix eval --impure --expr '
let
  flake = builtins.getFlake (toString ./.);
  cfg = flake.nixosConfigurations.aka.config;
in {
  sunshineApps = builtins.map (app: app.name) cfg.services.sunshine.applications.apps;
  hyprlandEnabled = cfg.programs.hyprland.enable or false;
  swayEnabled = cfg.programs.sway.enable or false;
  korriSwayRepair = cfg.services.korri.gameStream.sway.repair;
  intentPath = cfg.services.korri.gameStream.intentPath;
  sessionEnvFile = cfg.services.korri.gameStream.sessionEnvFile;
}
'
```

Expected:

- `sunshineApps` includes `"Korri Stream"`.
- `hyprlandEnabled = false`.
- `swayEnabled = true`.
- `korriSwayRepair = true`.
- `intentPath = "/run/user/1000/korri-game-stream/next-launch.json"` or equivalent.
- `sessionEnvFile = "/run/user/1000/korri-game-stream/session.env"` or equivalent.

## Deploy

Use the normal deployment path for aka. If running on aka directly:

```bash
sudo nixos-rebuild switch --flake .#aka
```

Ask before destructive or shared-state operations.

## Runtime validation

### 1. Confirm Sway session state

Under the Sway session on aka:

```bash
echo "$XDG_RUNTIME_DIR"
echo "$WAYLAND_DISPLAY"
echo "$SWAYSOCK"
swaymsg -t get_outputs
swaymsg -t get_tree
cat /run/user/1000/korri-game-stream/session.env
```

### 2. Confirm Sunshine

```bash
systemctl status sunshine
journalctl -u sunshine -b -f
```

Moonlight should show one generic app: `Korri Stream`.

### 3. Enqueue a launch intent

Foreground browser example:

```bash
KORRI_GAME_STREAM_INTENT_PATH=/run/user/1000/korri-game-stream/next-launch.json \
  korri-game-stream-enqueue -- /run/current-system/sw/bin/firefox https://example.com
```

Steam launcher example with session anchoring:

```bash
KORRI_GAME_STREAM_INTENT_PATH=/run/user/1000/korri-game-stream/next-launch.json \
  korri-game-stream-enqueue --lifecycle session -- /run/current-system/sw/bin/steam
```

Steam game URL example with session anchoring:

```bash
KORRI_GAME_STREAM_INTENT_PATH=/run/user/1000/korri-game-stream/next-launch.json \
  korri-game-stream-enqueue --lifecycle session -- /run/current-system/sw/bin/steam steam://rungameid/<APP_ID>
```

Optional monitor command example:

```bash
WAIT_JSON='{"command":"/absolute/wait-for-game-exit","args":[]}'
KORRI_GAME_STREAM_INTENT_PATH=/run/user/1000/korri-game-stream/next-launch.json \
  korri-game-stream-enqueue --lifecycle session --wait-json "$WAIT_JSON" -- /run/current-system/sw/bin/steam steam://rungameid/<APP_ID>
```

Cwd/env example:

```bash
KORRI_GAME_STREAM_INTENT_PATH=/run/user/1000/korri-game-stream/next-launch.json \
  korri-game-stream-enqueue --cwd /tmp --env FOO=bar -- /absolute/command arg1 arg2
```

### 4. Launch from Moonlight

1. Open Moonlight.
2. Launch `Korri Stream`.
3. Confirm the enqueued process starts.
4. Confirm Sway/Gamescope fullscreen repair works.
5. Exit the foreground process, or stop the session for `--lifecycle session` launches.
6. Confirm the Korri runner exits and Sunshine session behavior is correct.

Runner diagnostics:

```bash
tail -f ~/.local/state/korri/game-stream-runner.log
cat /run/user/$(id -u)/korri-game-stream/status.json
```

## Troubleshooting

- If `Korri Stream` exits immediately, check pending intent path, intent expiry, and the Sway env file.
- If the runner says no pending intent, ensure enqueue and runner use the same `KORRI_GAME_STREAM_INTENT_PATH`.
- If the runner says `SWAYSOCK is required for Sway repair`, fix session env export from Sway.
- If fullscreen repair fails, inspect `swaymsg -t get_tree` and the runner log.
- If a launcher command returns immediately, enqueue it with `--lifecycle session`.
- If a session-anchored launch stays open after the app exits, provide a `--wait-json` monitor command or stop the Moonlight/Sunshine session manually.
- If the local Korri path input is unavailable on the build machine, build from the machine that has `/home/simonwjackson/code/sandbox/korri` or switch the input to a pushed GitHub ref.

## Final response expected

When done, summarize:

- Files changed in Mountainous.
- Exact Korri input used.
- How aka is configured to use Sway.
- How Hyprland is kept disabled.
- Whether evaluated config shows Sway enabled and Hyprland disabled.
- Whether `Korri Stream` appears in Sunshine apps.
- Intent path and session env file paths.
- Build/deploy command and result.
- Runtime validation result, or the next manual step.
