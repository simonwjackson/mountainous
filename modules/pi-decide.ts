// Ship this provider with the app profile, not with host-owned settings.
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { builtinProviders } from "@earendil-works/pi-ai/providers/all";

export default function (pi: ExtensionAPI) {
  if (!process.env.PI_DECIDE_API_KEY) return;
  // pi 1.2.0's extension loader aliases the pi-ai root to compat.js. Its
  // explicit providers/all alias works; arbitrary api/* subpaths do not.
  // This provider's classify dispatches to the built-in System One adapter.
  const classify = builtinProviders().find((provider) => provider.id === "typesafe")?.classify;
  if (!classify) throw new Error("Built-in TypeSafe System One classifier is unavailable");
  const baseUrl = "https://ai.hummingbird-lake.ts.net/v1";
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
