import Quickshell

// Run with the offline CLI fixture first in PATH; see the storage repair runbook.
Scope {
    StorageHealth {
        screen: Quickshell.screens[0]
        shown: true
        onRowsChanged: console.log("storage-health preview: " + rows.length + " rows, " + state)
        onStateChanged: console.log("storage-health preview state: " + state)
    }
}
