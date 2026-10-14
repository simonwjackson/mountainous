// Exercise the same module and Bun runtime as the shipped CLI, without inference.
import assert from 'node:assert/strict';
import { readFileSync, mkdirSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { pathToFileURL } from 'node:url';

const [modulePath, agentDir, expectedPath] = process.argv.slice(2);
const { SettingsManager } = await import(pathToFileURL(modulePath).href);
const expected = JSON.parse(readFileSync(expectedPath, 'utf8'));
const cwd = mkdtempSync(join(tmpdir(), 'pi-policy-project-'));
try {
  mkdirSync(join(agentDir, 'settings.json.lock'), { recursive: true });
  const manager = SettingsManager.create(cwd, agentDir);
  assert.deepEqual(manager.getGlobalSettings(), expected);
  assert.deepEqual(manager.getSettings(), expected);
  assert.equal(manager.getDefaultProvider(), expected.defaultProvider);
  assert.equal(manager.getDefaultModel(), expected.defaultModel);
  console.log('locked global settings remain effective despite a pre-made lock');

  const broken = mkdtempSync(join(tmpdir(), 'pi-policy-broken-'));
  try {
    // Missing, empty and malformed policy must not start with {}.
    assert.throws(() => SettingsManager.create(cwd, broken));
    for (const text of ['', '{malformed']) {
      writeFileSync(join(broken, 'settings.json'), text);
      assert.throws(() => SettingsManager.create(cwd, broken));
    }
  } finally {
    rmSync(broken, { recursive: true, force: true });
  }
  console.log('global policy read/parse failures abort settings construction');
} finally {
  rmSync(cwd, { recursive: true, force: true });
}
