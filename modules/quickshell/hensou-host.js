.pragma library

// QsWindow.window is QObject in the QML metadata but exposes native DPR at
// runtime. Keep this dynamic host check out of shared drawing and typed QML.
function devicePixelRatio(window) {
    const ratio = window ? window.devicePixelRatio : 0;
    return typeof ratio === "number" && isFinite(ratio) && ratio > 0 ? ratio : 1.5;
}
