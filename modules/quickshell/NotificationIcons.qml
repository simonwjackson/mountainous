pragma Singleton

import Quickshell
import QtQuick
import "notification-model.js" as Model

// The icon a notification shows, for the popups and the centre alike.
// Model.iconChoice sets the order; the platform lookups live here.
// Quickshell answers a missing icon with "", which these turn into none.
Singleton {
    function choice(item) {
        return Model.iconChoice(item,
            function (name) {
                const url = Quickshell.iconPath(name, true);
                return url !== "" ? Model.some(url) : Model.none();
            },
            function (appName) {
                const entry = DesktopEntries.heuristicLookup(appName);
                const url = entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : "";
                return url !== "" ? Model.some(url) : Model.none();
            });
    }
}
