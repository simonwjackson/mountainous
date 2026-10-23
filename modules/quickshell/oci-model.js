.pragma library

// The helper emits percent as a numeric string or '--'. Never borrow another
// profile's tone. Keep name/value separate for opposite-edge row alignment.
/**
 * @param {{name?: string, percent?: unknown} | null | undefined} row
 * @returns {{tone: 'normal'|'warning'|'danger', name: string, value: string, failed: boolean}}
 */
function rowRule(row) {
    const raw = row ? row.percent : undefined;
    const numeric = typeof raw === "number" || (typeof raw === "string" && raw.trim() !== "");
    const percent = numeric ? Number(raw) : NaN;
    const failed = !Number.isFinite(percent) || percent < 0;
    return {
        name: row && typeof row.name === "string" ? row.name : "",
        value: failed ? "Failed" : percent.toFixed(1) + "%",
        tone: failed ? "warning" : percent >= 80 ? "danger" : percent >= 50 ? "warning" : "normal",
        failed: failed
    };
}
