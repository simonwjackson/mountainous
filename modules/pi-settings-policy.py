"""Patch the reviewed, unbundled Bun SettingsManager; fail closed on drift."""
import hashlib
from pathlib import Path
import sys


def patch(dist):
    path = dist / "core/settings-manager.js"
    source = path.read_text()
    expected = "4c6c9023a6178588e29545f3bc8d52ceb65ed44b58ce8dd72c9ef38f040e745f"
    if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
        raise SystemExit("pi settings policy: upstream SettingsManager changed; review the patch before updating")
    if 'import { main } from "./main.js";' not in (dist / "cli.js").read_text():
        raise SystemExit("pi settings policy: CLI is no longer the reviewed unbundled entry point")
    main = (dist / "main.js").read_text()
    if ('import { SettingsManager } from "./core/settings-manager.js";' not in main or
            'const bootstrapSettingsManager = SettingsManager.create(cwd, agentDir, { projectTrusted: false });' not in main):
        raise SystemExit("pi settings policy: startup no longer uses the reviewed SettingsManager")
    definitions = [p.relative_to(dist).as_posix() for p in dist.rglob("*") if p.suffix in {".js", ".mjs", ".cjs"} and "class SettingsManager" in p.read_text()]
    if definitions != ["core/settings-manager.js"]:
        raise SystemExit("pi settings policy: unexpected embedded/bundled SettingsManager")
    replacements = [
        ('''    withLock(scope, fn) {
        const path = scope === "global" ? this.globalSettingsPath : this.projectSettingsPath;''', '''    withLock(scope, fn) {
        // Fleet global policy is immutable; a user-owned lock must never hide it.
        if (scope === "global") {
            const current = readFileSync(this.globalSettingsPath, "utf-8");
            if (fn(current) !== undefined) {
                throw new Error("Global pi settings are Nix-owned and read-only");
            }
            return;
        }
        const path = scope === "global" ? this.globalSettingsPath : this.projectSettingsPath;'''),
        ('''        if (!content) {
            return {};
        }
        const settings = JSON.parse(stripBom(content));''', '''        if (!content && scope !== "global") {
            return {};
        }
        const settings = JSON.parse(stripBom(content));'''),
        ('''        catch (error) {
            return { settings: {}, error: error };
        }''', '''        catch (error) {
            if (scope === "global") throw error;
            return { settings: {}, error: error };
        }'''),
    ]
    for before, after in replacements:
        if source.count(before) != 1:
            raise SystemExit("pi settings policy: patch context changed")
        source = source.replace(before, after)
    path.write_text(source)


if __name__ == "__main__":
    patch(Path(sys.argv[1]))
