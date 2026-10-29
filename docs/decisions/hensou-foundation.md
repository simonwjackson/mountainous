# Hensou foundation host boundary

The shell consumes the `Hensou` Qt Quick module from the pinned Hensou input's
`hensou-qml` package (`lib/qt-6/qml`). Its independent `chicagoflf` and
`w95fa-grid` packages also provide the shell's existing font package names.
Terminal fonts remain in Mountainous. There is one authoritative W95FA transform
in Hensou, not a second copy in Mountainous.

This is an extraction of existing drawing, not a redesign. No public theme IDs
change: persisted `platinum` and `win98` keep their meaning. The module exports a
selected set of actual buttons, fields, checkboxes, list drawing and frame/icon
support. No desktop/service owners move into the kit.

## Identity and persistence

Shell QML uses **qualified** `import Hensou as Kit`. The flat shell `Theme.qml`
is still the host adapter. It owns FileView watching, theme registry lookup,
icon theme changes before Desktop loading, sounds preferences, diagnostics and
IPC. It forwards appearance values to the sole `Kit.Theme` singleton. Shared
tokens reference that same singleton. There are no local token singleton files
and no directory imports of Hensou.

This avoids unqualified `Theme` collisions and duplicate state. The real-engine
lifecycle probe reads both names and verifies the host-specific watcher/sound/
recovery properties exist on local Theme, including after live file changes and
rollback. Existing ThemeDesktop and ThemePicker recovery paths stay in place.

## Flat delivery and scale

Root shell delivery remains flat, with no root qmldir. Small local subclasses
retain the old control type names for Quickshell's static-import preprocessing
and dynamic Desktop/picker loads. These are host adapters, not alternate paint
implementations. The kit's own qmldir is a separate URI module.

Each adapter binds `hensouDevicePixelRatio` to its actual `QsWindow.window`.
Shared controls find the nearest provider (apps use `Kit.WindowScale`). No shell
window writes a global token DPR. Platinum shell-only drawing calls token
helpers with its actual QsWindow too. Two differently scaled windows must not
change one another's geometry. Win98 keeps exactly two physical pixels per unit,
including DPR 1.5. Screen DPR is not a substitute for QsWindow DPR.

The ancestor provider also supplies the shell's icon-theme URL resolver. Shared
SVG string tables are generated at development/package time and work outside
the shell root. They require no FileView, XMLHttpRequest or file-read permission.

## Input ownership and cost

Platinum's shell checkbox remains drawing-only, and its shell button keeps
`keyboardEnabled:false`. The existing menu host owns keys/focus. Standalone
apps opt into checkbox interaction and ordinary tab focus. Existing Win98
checkbox handlers ignore the additive next-value signal argument and still
invert owner state once. The controls never also mutate owner-bound `checked`.

Cost: adapters still exist for each selected drawing type, and the shell must
keep the imported module reachable during an activation. The ordered Hjem
restart remains the activation completion boundary. There is no new activation
or deployment behavior here. Hosts still own native popup escape, modality,
focus return, full-label disclosure and persistence. The foundation does not
solve those application-composition responsibilities by drawing a frame.
