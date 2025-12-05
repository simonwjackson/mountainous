# Plan: Xbox Button Logic - Steam Special Workspace + Games on Workspace 10

**Issue**: rethink-20
**Status**: Planning
**System**: kuju (GPD Win Mini 2025)

## Goal

Implement Xbox button behavior where:
- Steam client lives in a special workspace called "gaming"
- Games (steam_app_*, gamescope) display on workspace 10
- Xbox button provides context-aware navigation

## Desired Behavior

### State Machine

```
┌─────────────────────────────────────────────────────────────────┐
│                     XBOX BUTTON PRESSED                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────┐     ┌───────────────────────────────────┐ │
│  │ On workspace 10? │ NO  │ Game running on ws10?             │ │
│  │                  │────>│                                   │ │
│  └────────┬─────────┘     └───────────────┬───────────────────┘ │
│           │ YES                           │                     │
│           ▼                               │                     │
│  ┌──────────────────┐                     │ YES    │ NO         │
│  │ Toggle special   │                     ▼        ▼            │
│  │ workspace        │     ┌────────────┐  ┌─────────────────┐   │
│  │ "gaming"         │     │ Switch to  │  │ Switch to ws10  │   │
│  └──────────────────┘     │ ws10 (show │  │ + show special  │   │
│                           │ the game)  │  │ workspace       │   │
│                           └────────────┘  └─────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Detailed Logic

1. **Already on workspace 10**: Toggle the "gaming" special workspace (shows/hides Steam overlay)

2. **Not on workspace 10 + Game running on ws10**: Switch to workspace 10 to show the game (don't toggle special workspace yet - user can press again to access Steam)

3. **Not on workspace 10 + No game running**: Switch to workspace 10 AND show the "gaming" special workspace (ready to launch a game)

## Implementation Details

### Files to Modify

1. **`nix/systems/x86_64-linux/kuju/home.nix`**
   - Update Xbox button binding to use a script instead of inline command
   - Update windowrule to put Steam client in special:gaming
   - Keep games on workspace 10

2. **`nix/packages/` (new)** or inline script
   - Create xbox-button-handler script with the state machine logic

### Window Rules Changes

**Current**:
```nix
windowrule = [
  "workspace 10 silent, match:class (steam|Steam)"
  "workspace 10 silent, match:title Steam"
  "workspace 10, match:class r:^steam_app_"
  "workspace 10, match:class gamescope"
  "fullscreen on, match:class r:^steam_app_"
  "fullscreen on, match:class gamescope"
];
```

**Proposed**:
```nix
windowrule = [
  # Steam client goes to special workspace "gaming"
  "workspace special:gaming, match:class ^(steam|Steam)$"
  "workspace special:gaming, match:title ^Steam$"

  # Games go to workspace 10
  "workspace 10, match:class r:^steam_app_"
  "workspace 10, match:class gamescope"

  # Games are fullscreen
  "fullscreen on, match:class r:^steam_app_"
  "fullscreen on, match:class gamescope"
];
```

### Xbox Button Script Logic

```bash
#!/usr/bin/env bash
# xbox-button-handler

CURRENT_WS=$(hyprctl activeworkspace -j | jq -r '.id')
GAME_ON_WS10=$(hyprctl clients -j | jq -r '[.[] | select(.workspace.id == 10 and (.class | test("^steam_app_|gamescope")))] | length')
SPECIAL_VISIBLE=$(hyprctl activeworkspace -j | jq -r '.name | startswith("special:")')

if [[ "$CURRENT_WS" == "10" ]]; then
    # Already on workspace 10 - toggle special workspace
    hyprctl dispatch togglespecialworkspace gaming
elif [[ "$GAME_ON_WS10" -gt 0 ]]; then
    # Not on ws10, but game is running there - go to it
    hyprctl dispatch workspace 10
else
    # Not on ws10, no game - show Steam to launch one
    hyprctl dispatch workspace 10
    hyprctl dispatch togglespecialworkspace gaming
fi
```

### Base Hyprland Conflict Resolution

The base `windowrules.nix` has:
```nix
"workspace magic, match:class ^(steam)$"
```

This needs to be:
1. Overridden by kuju-specific rules (should work due to append order)
2. Or removed from base config if not used elsewhere

**Decision**: The kuju-specific rules will take precedence since they're appended last, but we should verify this works.

## Implementation Steps

### Phase 1: Create Xbox Button Handler Script
1. Create `nix/packages/xbox-button-handler/default.nix`
2. Implement the state machine logic
3. Use jq for JSON parsing of hyprctl output

### Phase 2: Update Kuju Home Configuration
1. Update `nix/systems/x86_64-linux/kuju/home.nix`
2. Change windowrule for Steam client: `workspace 10` → `workspace special:gaming`
3. Keep game rules pointing to workspace 10
4. Update bind to use the new handler script

### Phase 3: Test & Verify
1. Build and deploy: `just switch kuju`
2. Test scenarios:
   - Press Xbox from desktop → should go to ws10 + show Steam
   - Launch game → game appears on ws10
   - Press Xbox during game → should toggle Steam overlay
   - Press Xbox from other workspace with game running → should switch to ws10

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Rule conflict with base magic workspace | Verify kuju rules override base rules |
| Script execution latency | Keep script minimal, use local hyprctl |
| Special workspace not hiding correctly | Test both show and hide transitions |
| Game detection regex miss | May need to expand regex patterns |

## Rollback Plan

If issues occur, revert to previous behavior:
1. Keep backup of current home.nix
2. `git checkout` can restore previous config
3. Previous behavior worked for basic workspace switching

## Success Criteria

- [ ] Xbox button from non-ws10 with no game → goes to ws10, shows Steam
- [ ] Xbox button from ws10 → toggles Steam special workspace
- [ ] Xbox button from non-ws10 with game running → goes to ws10 (shows game)
- [ ] Steam client always appears in special workspace, not ws10 directly
- [ ] Games always appear on ws10, fullscreen
- [ ] No conflicts with base Hyprland config
