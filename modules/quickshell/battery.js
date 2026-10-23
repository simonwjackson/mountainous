.pragma library

// Percent is 0..100 (UPower reports 0..1; QML converts at the boundary).
// charging/full are explicit UPower device states, not guesses from AC alone.
/**
 * @param {number} percent
 * @param {boolean} charging
 * @param {boolean} full
 * @param {boolean} onBattery
 * @returns {{tone: 'normal'|'warning'|'danger', indicator: 'bolt'|'plug'|'none'}}
 */
function rule(percent, charging, full, onBattery) {
    const known = typeof percent === "number" && Number.isFinite(percent) && percent >= 0 && percent <= 100;
    return {
        tone: onBattery && known ? (percent <= 10 ? "danger" : percent <= 20 ? "warning" : "normal") : "normal",
        indicator: onBattery ? "none" : full ? "plug" : charging ? "bolt" : "none"
    };
}
