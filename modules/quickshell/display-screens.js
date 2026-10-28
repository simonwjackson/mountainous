.pragma library
// Hyprland publishes only enabled workspace destinations, not mirror sinks.
// Qt can still expose a QScreen for each lit connector. Preview compositors
// have no Hyprland session and keep their own screen list.
function desktops(screens, monitors, hyprlandSession) {
    if (!hyprlandSession) return screens;
    return screens.filter(function (screen) {
        return monitors.some(function (monitor) { return monitor.name === screen.name; });
    });
}
