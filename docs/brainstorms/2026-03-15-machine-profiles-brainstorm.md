---
date: 2026-03-15
topic: machine-profiles
---

# Machine Profiles

## What We're Building
A clearer host classification model where a machine can opt into multiple independent profiles instead of being forced into a single overloaded machine type. The current focus is narrowing that model around two broad profiles:

- `desktop`: machines with a local graphical session and GUI-oriented user experience
- `portable`: machines with laptop/mobile power, sleep, lid, and battery behavior

The immediate goal is to identify what can be moved out of `hosts/yuki/default.nix` into these shared profiles, while keeping genuinely host-specific quirks on `yuki`.

## Why This Approach
`yuki` currently mixes three kinds of configuration in one host file:
1. broad graphical-machine defaults,
2. broad laptop/portable defaults,
3. Yoga Book 9i-specific quirks.

Separating those concerns will make the host file easier to read, reduce duplication for future machines, and avoid turning `yuki` into the accidental template for every GUI laptop.

The right split is not “move everything possible” but “move only what is broadly true for most desktop or portable machines.” Model-specific hardware workarounds should stay local.

## Key Decisions
- `desktop` should mean “local graphical machine,” not “non-laptop.” A laptop like `yuki` can and should be both `desktop` and `portable`.
- `portable` should mean “battery/lid/suspend/mobile hardware behavior,” not “has a GUI.”
- Shared profiles should take only broadly reusable defaults; machine-specific hardware quirks stay in `hosts/yuki/quirks.nix` or `hosts/yuki/default.nix`.
- `yuki` should get thinner by moving broad defaults first and leaving risky hardware behavior local until another machine proves the pattern.

## Resolved Questions
- `desktop` does not imply a non-laptop machine.
- The current extraction focus should be `desktop` and `portable`, not the full machine-profile space.
- `desktop` should be opinionated: it can represent your default graphical stack rather than a minimal GUI abstraction.
- Kanata should be treated as a broad personal-ergonomics default for machines where you use a keyboard, not as a yuki-only quirk.

## Candidate Extractions from `hosts/yuki/default.nix`

### Move to `desktop`
These read as broad graphical-machine defaults rather than yuki-only behavior:
- `programs.dconf.enable = true`
- `programs.hyprland.enable = true` with `xwayland.enable = true`
- `xdg.portal = { ... }`
- `services.greetd = { ... }`
- GUI-oriented Home Manager imports/defaults that are part of your standard desktop stack, such as theme wiring
- possibly `fonts.packages = [ nerd-fonts.symbols-only ]` if that is a general desktop preference

Because `desktop` is now explicitly opinionated, it is reasonable for it to mean “my normal Hyprland-based graphical environment” rather than a desktop-agnostic abstraction.

### Move to `portable`
These look like broadly reusable laptop/mobile defaults:
- `networking.networkmanager.wifi.powersave = true`
- `services.tlp.enable = true`
- `services.upower.enable = true`
- `services.logind.settings.Login` lid-switch behavior, if this is your preferred baseline for laptops
- `systemd.sleep.extraConfig = "HibernateDelaySec=15min"`
- `services.auto-cpufreq.enable = mkForce false` if TLP is your standard portable policy
- battery/performance tuning under `services.tlp.settings`, but probably only the generic parts

### Probably keep on `yuki`
These currently look too host-specific to promote yet:
- `./quirks.nix` import and nearly everything inside it
- Yoga Book dual-screen display setup and HyprDynamicMonitors integration
- Bluetooth unblock workaround
- `services.xserver.videoDrivers = [ "modesetting" ]`
- exact swap layout
- exact `boot.kernelPackages` choice
- user extra groups like `networkmanager` / `video` if they are not universal portable defaults
- `mountainous.device` values if they are still more descriptive metadata than active shared behavior

### Re-home, but not under `desktop`/`portable`
These should move out of `yuki`, but deserve their own shared place:
- Kanata config and service

Given your requirement, Kanata sounds like a cross-machine input/profile concern: “machines where I use a physical keyboard.” That likely wants a dedicated shared profile or feature rather than living under `portable` or `desktop`.

## Open Questions
- Should `portable` include opinionated suspend/lid behavior immediately, or start smaller with only battery/power-management defaults?
- Do you want desktop Home Manager concerns like theme imports to live under the same profile layer as NixOS machine profiles?
- What should the shared home for Kanata be: a dedicated `input`/`keyboard` profile, or a standalone feature?

## Next Steps
→ `/forgerie:spec` for implementation details
