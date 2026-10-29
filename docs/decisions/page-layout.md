# Page layout backend

`page-layout.lua` owns page settings and compaction. `hyprland.lua` binds its
public functions. Session restore receives a `capacity[id]` view of that same
store, including writes for pages it has not created yet. It does not own a
second capacity table. Releasing restore discards overrides for missing pages.

The state and command contracts in `docs/plans/page-layout-control.md` are
unchanged. Monitor defaults use descriptions on disk and connectors on the
runtime wire. The runtime state file also restores page settings on a config
reload. A separate runtime file stores only addresses of page-floated windows,
so a reload can still distinguish them from hand-floated windows. No settings
are duplicated there. Atomic replacement uses a sibling `.tmp` file.
Super+Ctrl+F calls the module's manual window toggle. It clears and persists
page float ownership before dispatching the toggle, so a tile/refloat sequence
and a config reload cannot reclaim a hand-floated window.

Super+Shift+bracketleft and Super+Shift+bracketright change the outer gap by
-4/+4. Plain Super+bracketleft/right keep the existing cycleprev/cyclenext
bindings. Hyprland runs duplicate bindings, so the gap actions need Shift.

Zen no longer maximizes the focused window. A page can have two or three tiled
windows; maximizing one hides the others and makes a page setting depend on
focus. Zen now only applies page margins. Super+M remains the independent
monocle command. The existing `hypr-zen` command and omni action stay intact.

## Hyprland 0.56.2 source facts

Source root: `/nix/store/xm2laz7bplbf2wnsx9p4iaxcy95gmv1k-source`.
Paths below are relative to `src/`. These are the actual Lua bindings, not
legacy configuration names.

| Use | Source and quoted line |
| --- | --- |
| Workspace selector must be a string | `config/lua/bindings/LuaBindingsConfigRules.cpp:636`: `hl.workspace_rule: 'workspace' field is required and must be a string` |
| Outer gaps | Same file, line 206: `{"gaps_out", []() -> ILuaConfigValue* { return new CLuaConfigCssGap(20); },` |
| Four independent margins | `config/lua/types/LuaConfigCssGap.cpp:31`: `css_gap type requires an integer or a table with optional "top", "right", "bottom", "left" fields` |
| Replacing rules | `config/lua/bindings/LuaBindingsConfigRules.cpp:729`: `const auto RULE = Config::workspaceRuleMgr()->replaceOrAdd(std::move(wsRule));` |
| Replacement identity | `config/shared/workspace/WorkspaceRuleManager.cpp:26`: `r->isEnabled() && r->m_workspaceString == x.m_workspaceString`; line 30: `(*it)->mergeLeft(x);` |
| Disabling rules; no remove method | `config/lua/objects/LuaWorkspaceRule.cpp:62-67`: `if (key == "set_enabled")` / `else if (key == "is_enabled")` / `else lua_pushnil(L);`. Line 40: `rule->setEnabled(lua_toboolean(L, 2));` |
| Rule refresh | Same file, line 41: `scheduleRefresh(Config::Supplementary::REFRESH_MONITOR_STATES \| Config::Supplementary::REFRESH_WINDOW_STATES)` |
| Window float dispatcher | `config/lua/bindings/LuaBindingsDispatchers.cpp:721-726`: `hlWindowFloat` calls `Internal::tableToggleAction(L, 1)` and `Internal::pushWindowUpval(L, 1)` |
| Float action vocabulary | `config/lua/bindings/LuaBindingsInternal.cpp:309-312`: `str == "enable" \|\| str == "on"` / `str == "disable" \|\| str == "off"`. These are **not** fullscreen's set/unset actions. |
| Addressed window selection | Same file, line 325: `tableOptWindowSelector(L, tableIdx, "window", "window selector")`; line 320: `query().selector(lua_tostring(L, lua_upvalueindex(idx))).runWindow()` |
| Window address, floating, pinned | `config/lua/objects/LuaWindow.cpp:70-71`: `key == "address"`, `std::format("0x{:x}", reinterpret_cast<uintptr_t>(w.get()))`; lines 97-98: `key == "floating"`, `w->m_isFloating`; lines 117-118: `key == "pinned"`, `w->m_pinned` |
| Workspace windows | `config/lua/objects/LuaWorkspace.cpp:55-58`: `for (auto const& w : Desktop::windowState()->windows())` and `if (w->m_workspace == ws)`; lines 115-116: `key == "windows"`, `ws->getWindowCount()` |
| Move to workspace | `config/lua/bindings/LuaBindingsDispatchers.cpp:860-867`: `tableOptWorkspaceSelector(L, 1, "workspace", "hl.window.move")`, optional `"follow"`, and `Internal::pushWindowUpval(L, 1)` |
| Renumbering | Same file, lines 1298-1301: `expected a table { workspace, id }`, `requireTableFieldWorkspaceSelector(..., "workspace", ...)`, `requireTableFieldNum(..., "id", ...)`; `desktop/Workspace.cpp:553`: `m_id = id;` |
| Open, destroy events | `config/lua/LuaEventHandler.cpp:94-97`: `dispatch("window.open", 1, ...)`, `dispatch("window.destroy", 1, ...)` |
| Move event and arguments | Same file, lines 111-115: `dispatch("window.move_to_workspace", 2, ...)`, `CLuaWindow::push(L, w);`, `CLuaWorkspace::push(L, ws);` |
| Move event timing | `desktop/view/Window.cpp:570`: `m_workspace = pWorkspace;`; line 581: `window.moveToWorkspace.emit(m_self.lock(), pWorkspace);`. The method continues after the emission, so float/enforcement waits one timer tick and looks up the live address. |
| Workspace creation timing | `desktop/Workspace.cpp:30-32`: `workspace->init(workspace);` precedes `State::workspaceState()->add(workspace);`; line 74: `workspace.created.emit(self);` runs inside `init`. Refresh waits one tick so an empty page reaches the registry before publication and rule application. |
| Expired workspace references | `config/lua/objects/LuaWorkspace.cpp:97-101`: `if (!ws || ws->inert())` calls `lua_pushnil(L);`. Reset checks the id first and skips expired targets after earlier overflow operations move focus. |
| Workspace lifecycle | `config/lua/LuaEventHandler.cpp:137`: `dispatch("workspace.created", 1, ...)`; line 142: `dispatch("workspace.removed", 1, ...)`; line 145: `dispatch("workspace.move_to_monitor", 2, ...)` |
| Monitor and start events | Same file, lines 121-124: `"monitor.added"`, `"monitor.removed"`, `"monitor.layout_changed"`; line 165: `dispatch("hyprland.start", 0, ...)` |
| Monitor identity and size | `config/lua/objects/LuaMonitor.cpp:87-88`: `key == "description"`, `mon->m_shortDescription`; lines 91-94: `"width"`/`"height"` expose `m_pixelSize.x`/`.y`; lines 127-130 expose `"scale"`/`"transform"` |
| Active ordinary page | Same file, lines 105-109: `key == "active_workspace"`, `CLuaWorkspace::push(L, mon->m_activeWorkspace)`; lines 168-169: `key == "focused"`, `mon == Desktop::focusState()->monitor()` |
| Rotated logical size | `output/Monitor.cpp:1058-1059`: `Vector2D xfmd = m_transform % 2 == 1 ? Vector2D{m_pixelSize.y, m_pixelSize.x} : m_pixelSize;` / `m_size = (xfmd / m_scale).round();` |
| Deferred work | `config/lua/bindings/LuaBindingsToplevel.cpp:466-485`: `"timeout"` is milliseconds greater than zero; `"type"` must be `"repeat"` or `"oneshot"`. |
| Dispatch failures | `config/lua/bindings/LuaBindingsInternal.cpp:357-372`: `pushSuccessResult` sets `"ok"` to true; `pushErrorResult` sets `"ok"` to false and `"error"` to the message. The module checks this result before transferring ownership or renumbered settings. |
| Eval error response | `debug/HyprCtl.cpp:1119-1123`: `auto err = luaMgr->eval(...)`; `if (err) return *err;`; `return "ok";`. Helpers check the reply, not just the process exit code. |

Rules are re-enabled before replacement when an id is reused. Disabling first
and discarding the handle would leave one disabled compositor rule per edit.
No compaction occurs on workspace creation or activation, to preserve the
existing gesture crash avoidance. Capacity and float operations on moved
windows run after the compositor has completed its move.

## Verification scope

The page-layout check runs Lua syntax validation, the actual module with a
headless `hl` adapter and real temporary JSON files, the production JavaScript
model against emitted JSON, shellcheck, and command argument/error tests.
The headless tests cover overflow, renumbering, monitor defaults and reloads,
float provenance, manual takeover and pins, non-colliding gap keys, rotated Zen, restore capacity, pre-registry creation, expired reset targets, lifecycle
publication, and the exact state-file fields.

Myoko's login is `simon` (uid 1000), not `simonwjackson`. Read-only monitor JSON
and Lua assertions verified its monitor fields and successful eval response.
No configuration was deployed and no desktop state was changed. Live window
placement/float behaviour remains a post-deployment verification step.
