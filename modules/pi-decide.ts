// Ship this provider with the app profile, not with host-owned settings.
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { classify } from "@earendil-works/pi-ai/api/typesafe-system-one";

export default function (pi: ExtensionAPI) {
  if (!process.env.PI_DECIDE_API_KEY) return;
  const baseUrl = "https://decide.hummingbird-lake.ts.net/v1";
  pi.registerProvider("decide", {
    apiKey: "$PI_DECIDE_API_KEY",
    baseUrl,
    models: ["jev", "solar", "fast"].map((id) => ({
      type: "classifier" as const,
      id,
      name: `Decide ${id}`,
      api: "typesafe-system-one" as const,
      baseUrl,
      input: ["text" as const],
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
      contextWindow: 128000,
    })),
    classifiers: { "typesafe-system-one": { classify } },
  });
}
