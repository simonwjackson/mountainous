# Prompt: Continue the aka Sway/Korri stream-host prototype

You are working in `/home/simonwjackson/code/github/simonwjackson/mountainous`.

Goal: continue the current aka prototype as a minimal Sway-based Korri stream host. Keep moving forward; avoid reintroducing broad Hyprland-oriented layers.

## Current prototype direction

`aka` should:

- run Sway, not Hyprland
- expose one generic Sunshine app named `Korri Stream`
- start Sunshine only after the Sway session has exported its runtime environment
- let Korri derive launch intent, status, and lock paths from the live session's `XDG_RUNTIME_DIR`
- avoid hard-coded `/run/user/1000/...` paths
- avoid `mountainous.presets.desktop` for this prototype
- avoid `mountainous.features.gaming` for this prototype
- add Steam/gaming pieces back later only deliberately, without Hyprland-specific wrappers

## Recent changes already made

In `hosts/aka/default.nix`, aka was simplified toward a focused Sway/Korri validation host.

### Desktop/gaming presets disabled

The broad desktop preset was disabled because it pulled in Hyprland-specific idle behavior such as `hyprctl dispatch dpms` through `hypridle`.

```nix
mountainous.presets = {
  core.enable = true;
  desktop.enable = false;
};
```

The broad gaming feature was disabled because it pulled in a Hyprland-oriented Steam wrapper via `steam-cage`.

```nix
mountainous.features = {
  bluetooth.enable = true;
  gaming.enable = false;
  hyprland.enable = false;
};
```

### Sway is explicit

```nix
programs = {
  hyprland.enable = false;
  sway = {
    enable = true;
    xwayland.enable = true;
  };
};
```

### Sunshine is started by Sway startup, not independently

```nix
services.sunshine = {
  enable = true;
  openFirewall = true;
  autoStart = false;
};
```

Sunshine still exposes the generic Korri app through the Korri module.

### Korri no longer gets static runtime paths

The earlier static path idea was intentionally removed. Do not set these for now:

```nix
services.korri.gameStream.intentPath = ...;
services.korri.gameStream.sessionEnvFile = ...;
```

The desired state is:

```nix
services.korri.gameStream = {
  enable = true;
  appName = "Korri Stream";
  intentMaxAgeSeconds = 300;

  gamescope.enable = true;
  sway.repair = true;
};
```

With `intentPath = null` and `sessionEnvFile = null`, Korri uses runtime-derived defaults from the Sunshine/Sway user session:

```text
$XDG_RUNTIME_DIR/korri-game-stream/next-launch.json
$XDG_RUNTIME_DIR/korri-game-stream/status.json
$XDG_RUNTIME_DIR/korri-game-stream/run.lock
```

This is intentional. Runtime directories are runtime facts, not static Nix host config facts.

### Sway startup was made ordered

The prior independent Sway `exec` lines were replaced by a single ordered startup script, roughly:

```nix
korriSwayStartup = pkgs.writeShellScript "korri-sway-startup" ''
  set -eu

  if [ -z "''${XDG_RUNTIME_DIR:-}" ]; then
    echo "korri-sway-startup: XDG_RUNTIME_DIR is required" >&2
    exit 1
  fi
  if [ -z "''${WAYLAND_DISPLAY:-}" ]; then
    echo "korri-sway-startup: WAYLAND_DISPLAY is required" >&2
    exit 1
  fi
  if [ -z "''${SWAYSOCK:-}" ]; then
    echo "korri-sway-startup: SWAYSOCK is required" >&2
    exit 1
  fi

  export XDG_CURRENT_DESKTOP=sway
  export XDG_SESSION_TYPE=wayland

  ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd \
    XDG_CURRENT_DESKTOP \
    XDG_SESSION_TYPE \
    XDG_RUNTIME_DIR \
    WAYLAND_DISPLAY \
    SWAYSOCK

  ${pkgs.coreutils}/bin/install -d -m 700 "$XDG_RUNTIME_DIR/korri-game-stream"
  ${pkgs.systemd}/bin/systemctl --user start sunshine.service
'';
```

And Sway config now calls only that script:

```nix
home-manager.users.simonwjackson.xdg.configFile."sway/config".text = ''
  include ${pkgs.sway}/etc/sway/config
  exec_always ${korriSwayStartup}
'';
```

## Validation already run

The current eval showed the desired shape:

```json
{
  "desktop": false,
  "gaming": false,
  "hypridle": false,
  "hyprlandEnabled": false,
  "mountainousHyprland": false,
  "swayEnabled": true,
  "korriSwayRepair": true,
  "intentPath": null,
  "sessionEnvFile": null,
  "sunshineApps": ["Korri Stream"],
  "sunshineAutoStart": false,
  "steam": false
}
```

These commands succeeded:

```bash
nix eval --impure .#nixosConfigurations.aka.config.system.build.toplevel.drvPath
nix build .#nixosConfigurations.aka.config.system.build.toplevel --dry-run
nix build --no-link --print-out-paths .#nixosConfigurations.aka.config.services.korri.gameStream.package
```

The Sunshine app eval showed:

```json
[
  {
    "auto-detach": false,
    "cmd": "/nix/store/...-korri-game-stream-sunshine-app",
    "name": "Korri Stream",
    "output": "/home/simonwjackson/.local/state/korri/game-stream-runner.log",
    "wait-all": true
  }
]
```

## Continue from here

1. Re-check the current diff in Mountainous.
2. Preserve the minimal Sway/Korri shape above.
3. Do not reintroduce static `/run/user/1000/...` Korri paths unless there is a concrete runtime reason.
4. Do not enable the desktop preset just to get desktop niceties; add specific Sway-compatible pieces if needed.
5. Do not enable the gaming feature just to get Steam; add Steam deliberately later if the prototype reaches Steam validation.
6. Keep Sunshine generic: one app, `Korri Stream`.
7. Keep Korri launch selection through trusted local intents.

## Useful validation command

Run this from the Mountainous repo root:

```bash
nix eval --impure --json --expr '
let
  flake = builtins.getFlake (toString ./.);
  cfg = flake.nixosConfigurations.aka.config;
in {
  desktop = cfg.mountainous.presets.desktop.enable;
  gaming = cfg.mountainous.features.gaming.enable;
  sunshineAutoStart = cfg.services.sunshine.autoStart;
  sunshineWantedBy = cfg.systemd.user.services.sunshine.wantedBy or [];
  sunshineApps = builtins.map (app: app.name) cfg.services.sunshine.applications.apps;
  hyprlandEnabled = cfg.programs.hyprland.enable or false;
  mountainousHyprland = cfg.mountainous.features.hyprland.enable or false;
  swayEnabled = cfg.programs.sway.enable or false;
  korriSwayRepair = cfg.services.korri.gameStream.sway.repair;
  intentPath = cfg.services.korri.gameStream.intentPath;
  sessionEnvFile = cfg.services.korri.gameStream.sessionEnvFile;
  hypridle = cfg.home-manager.users.simonwjackson.services.hypridle.enable or false;
  steam = cfg.programs.steam.enable or false;
}
'
```

Expected:

- `desktop = false`
- `gaming = false`
- `sunshineAutoStart = false`
- `sunshineWantedBy = []`
- `sunshineApps` includes `"Korri Stream"`
- `hyprlandEnabled = false`
- `mountainousHyprland = false`
- `swayEnabled = true`
- `korriSwayRepair = true`
- `intentPath = null`
- `sessionEnvFile = null`
- `hypridle = false`
- `steam = false`

Then run:

```bash
nix eval --impure .#nixosConfigurations.aka.config.system.build.toplevel.drvPath
nix build .#nixosConfigurations.aka.config.system.build.toplevel --dry-run
```

## Runtime validation after deployment

Once aka is switched and logged into Sway:

```bash
echo "$XDG_RUNTIME_DIR"
echo "$WAYLAND_DISPLAY"
echo "$SWAYSOCK"
swaymsg -t get_outputs
systemctl --user status sunshine
```

Confirm Moonlight sees exactly one generic app:

```text
Korri Stream
```

Enqueue a simple app before launching from Moonlight:

```bash
korri-game-stream-enqueue -- /run/current-system/sw/bin/foot
```

Then launch `Korri Stream` from Moonlight.

Expected runtime paths:

```bash
ls -la "$XDG_RUNTIME_DIR/korri-game-stream"
cat "$XDG_RUNTIME_DIR/korri-game-stream/status.json"
tail -f ~/.local/state/korri/game-stream-runner.log
```

## Open prototype questions

- Does Sunshine start reliably from the ordered Sway startup script?
- Does Moonlight see `Korri Stream` after Sway login?
- Does a simple `foot` launch render and exit cleanly?
- Does Gamescope + Sway fullscreen repair behave correctly?
- What explicit packages are needed for the next app/game validation?
- When Steam testing begins, should Steam be added directly rather than through `mountainous.features.gaming`?

## Final response expected

Summarize:

- Files changed.
- Whether aka still avoids `desktop` and `gaming` broad modules.
- Whether Hyprland remains disabled.
- Whether Sway remains enabled.
- Whether `Korri Stream` appears in Sunshine apps.
- Whether Korri paths remain runtime-derived.
- Build/eval results.
- Runtime validation result or next manual step.
