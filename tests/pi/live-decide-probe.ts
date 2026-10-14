// Explicit, opt-in live probe. Not run by builds or normal flake checks.
import { writeFileSync } from "node:fs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  // No chat inference is used. The fixture only permits normal CLI startup.
  pi.registerProvider("cliproxyapi", {
    api: "openai-completions", apiKey: "offline-chat-fixture",
    baseUrl: "http://127.0.0.1:9",
    models: [{ id: "gpt-5.6-sol", name: "Offline chat fixture", reasoning: true,
      input: ["text"], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
      contextWindow: 128000, maxTokens: 16384 }],
  });
  pi.on("session_start", async (_event, ctx) => {
    const results = [];
    for (const id of ["jev", "solar"]) {
      const model = ctx.modelRegistry.getModelOfType("classifier", "decide", id);
      if (!model) throw new Error(`Missing decide/${id}`);
      let wireModel: string | undefined;
      let wireType: string | undefined;
      let status: number | undefined;
      let billedCost: number | undefined;
      const result = await ctx.modelRegistry.classify(model, {
        state: { message: "The change works, thanks." },
        questions: { approved: { type: "bool", instructions: "Does the user approve of the change?",
          criteria: { true: "The user approves", false: "The user does not approve" } } },
      }, {
        timeoutMs: 60000, maxRetries: 0,
        onPayload: (payload) => {
          if (typeof payload === "object" && payload !== null && "questions" in payload) {
            const questions = payload.questions;
            if (typeof questions === "object" && questions !== null && "approved" in questions) {
              const approved = questions.approved;
              if (typeof approved === "object" && approved !== null && "type" in approved && typeof approved.type === "string") wireType = approved.type;
            }
          }
        },
        // Observe the real adapter's response; do not replace its HTTP client,
        // request generation, authentication, retries or answer parsing.
        fetch: async (url, init) => {
          const response = await fetch(url, init);
          status = response.status;
          const body: unknown = await response.clone().json();
          if (typeof body === "object" && body !== null && "model" in body && typeof body.model === "string") wireModel = body.model;
          const cost = response.headers.get("x-litellm-response-cost");
          if (cost !== null && Number.isFinite(Number(cost))) billedCost = Number(cost);
          return response;
        },
      });
      results.push({ requested: `decide/${id}`, model: result.model, wireModel, wireType,
        status, stopReason: result.stopReason, answers: result.answers, billedCost });
    }
    const output = process.env.PI_DECIDE_LIVE_OUTPUT;
    if (!output) throw new Error("Missing live probe output path");
    writeFileSync(output, JSON.stringify({ offline: process.env.PI_OFFLINE, results }), { mode: 0o600 });
    ctx.shutdown();
  });
}
