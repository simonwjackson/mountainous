import QtQuick

// Compile the optional CDP feature behind a filename boundary. A missing type
// or import stays a Loader error, never a reference in shell.qml's bindings.
Loader {
    source: "WebTheme.qml"
    asynchronous: true
    onStatusChanged: if (status === Loader.Error) console.warn("[web-theme] optional service failed to load; desktop and heartbeat remain active")
}
