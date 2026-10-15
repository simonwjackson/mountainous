// Exercise the shipped SettingsManager, including writes through the sync link.
import { pathToFileURL } from "node:url";
const [agent, directory, model] = process.argv.slice(2);
const { SettingsManager } = await import(pathToFileURL(
  agent + "/lib/node_modules/@earendil-works/pi-coding-agent/dist/core/settings-manager.js"
));
const manager = SettingsManager.create(directory, directory);
manager.setDefaultModelAndProvider("cliproxyapi", model);
manager.setEnabledModels(["cliproxyapi/" + model, "decide/*"]);
await manager.flush();
const errors = manager.drainErrors();
if (errors.length) throw new Error(JSON.stringify(errors));
