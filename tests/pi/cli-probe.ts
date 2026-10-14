// An offline extension reads the live session's settings through the public API.
// It never imports SettingsManager or opens agent/settings.json.
import { writeFileSync } from "node:fs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

function requiredEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing policy probe environment: ${name}`);
  return value;
}

export default function (pi: ExtensionAPI) {
  const provider = requiredEnv("PI_POLICY_PROVIDER");
  const model = requiredEnv("PI_POLICY_MODEL");
  // Make the configured model resolvable without credentials or an endpoint.
  pi.registerProvider(provider, {
    api: "openai-completions",
    apiKey: "offline-policy-test-not-a-secret",
    baseUrl: "http://127.0.0.1:9",
    models: [{
      id: model,
      name: "Offline policy probe",
      reasoning: true,
      input: ["text"],
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
      contextWindow: 262144,
      maxTokens: 16384,
    }],
  });
  pi.on("session_start", async (_event, ctx) => {
    const classifiers = await ctx.modelRegistry.getAvailableOfType("classifier", "decide");
    writeFileSync(requiredEnv("PI_POLICY_OUTPUT"), JSON.stringify({
      settings: pi.getSettings(),
      classifiers: classifiers.map((model) => `${model.provider}/${model.id}`).sort(),
      tools: pi.getActiveTools(),
    }));
    ctx.shutdown();
  });
}
