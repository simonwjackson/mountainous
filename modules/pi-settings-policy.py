"""Patch only immutable-global read methods; unrelated settings may change."""
from pathlib import Path
import sys

# Full methods are the anchors, not the whole module. This includes the lock,
# read, parse and fallback paths, but excludes settings declarations/getters.
WITH_LOCK = '''    withLock(scope, fn) {
        const path = scope === "global" ? this.globalSettingsPath : this.projectSettingsPath;
        const dir = dirname(path);
        let release;
        try {
            // Only create directory and lock if file exists or we need to write
            const fileExists = existsSync(path);
            if (fileExists) {
                release = this.acquireLockSyncWithRetry(path);
            }
            const current = fileExists ? readFileSync(path, "utf-8") : undefined;
            const next = fn(current);
            if (next !== undefined) {
                // Only create directory when we actually need to write
                if (!existsSync(dir)) {
                    mkdirSync(dir, { recursive: true });
                }
                if (!release) {
                    release = this.acquireLockSyncWithRetry(path);
                }
                writeFileSync(path, next, "utf-8");
            }
        }
        finally {
            if (release) {
                release();
            }
        }
    }'''
LOAD = '''    static loadFromStorage(storage, scope, projectTrusted = true) {
        if (scope === "project" && !projectTrusted) {
            return {};
        }
        let content;
        storage.withLock(scope, (current) => {
            content = current;
            return undefined;
        });
        if (!content) {
            return {};
        }
        const settings = JSON.parse(stripBom(content));
        return SettingsManager.migrateSettings(settings);
    }'''
TRY_LOAD = '''    static tryLoadFromStorage(storage, scope, projectTrusted = true) {
        try {
            return { settings: SettingsManager.loadFromStorage(storage, scope, projectTrusted), error: null };
        }
        catch (error) {
            return { settings: {}, error: error };
        }
    }'''
GLOBAL_READ = '''    withLock(scope, fn) {
        // Fleet global policy is immutable; a user-owned lock must never hide it.
        if (scope === "global") {
            const current = readFileSync(this.globalSettingsPath, "utf-8");
            if (fn(current) !== undefined) {
                throw new Error("Global pi settings are Nix-owned and read-only");
            }
            return;
        }'''
REGIONS = {
    "FileSettingsStorage.withLock": (WITH_LOCK, WITH_LOCK.replace('    withLock(scope, fn) {', GLOBAL_READ, 1)),
    "SettingsManager.loadFromStorage": (LOAD, LOAD.replace('if (!content)', 'if (!content && scope !== "global")', 1)),
    "SettingsManager.tryLoadFromStorage": (TRY_LOAD, TRY_LOAD.replace('        catch (error) {', '        catch (error) {\n            if (scope === "global") throw error;', 1)),
}


def patch(dist):
    canonical = dist / "core/settings-manager.js"
    candidates = [p for p in dist.rglob("*") if p.suffix in {".js", ".mjs", ".cjs"} and "class SettingsManager" in p.read_text()]
    if canonical not in candidates:
        raise SystemExit("pi settings policy: canonical SettingsManager definition missing")
    # Reject an unknown executable layout, without pinning startup statements.
    cli, main = (dist / "cli.js").read_text(), (dist / "main.js").read_text()
    if 'import { main } from "./main.js";' not in cli and "class SettingsManager" not in cli:
        raise SystemExit("pi settings policy: unknown CLI entry point")
    if ('import { SettingsManager } from "./core/settings-manager.js";' not in main and
            "class SettingsManager" not in main and "class SettingsManager" not in cli):
        raise SystemExit("pi settings policy: startup no longer uses the reviewed SettingsManager")
    patched = {}
    for path in candidates:
        source = path.read_text()
        # Use the same exact regions for any embedded/bundled copy. A changed,
        # missing or repeated method fails before any file is modified.
        for name, (before, after) in REGIONS.items():
            if source.count(before) != 1:
                raise SystemExit(f"pi settings policy: {name} patch context changed in {path.name}")
            source = source.replace(before, after, 1)
        patched[path] = source
    for path, source in patched.items():
        path.write_text(source)


if __name__ == "__main__":
    patch(Path(sys.argv[1]))
