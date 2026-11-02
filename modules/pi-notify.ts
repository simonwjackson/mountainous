// Tell the ntfy hub on Rakku when an interactive pi session finishes a turn.
// The fleet `notify` CLI (modules/notifications.nix) wraps the message in the
// envelope that notifyd accepts and reads its token from NOTIFY_TOKEN_FILE.
// Raw ntfy posts (pi-ntfy) would be rejected by notifyd's schema.
// Hosts without the CLI, and print/RPC sessions, send nothing.
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { basename } from "node:path";

const MAX_BODY = 200;

export default function (pi: ExtensionAPI) {
  pi.on("agent_end", async (event, ctx) => {
    if (!ctx.hasUI || !process.env.NOTIFY_TOKEN_FILE) return;

    let preview = "";
    for (const msg of [...event.messages].reverse()) {
      if (msg.role !== "assistant" || !Array.isArray(msg.content)) continue;
      for (const block of msg.content) {
        if (block.type === "text" && block.text) {
          preview = block.text;
          break;
        }
      }
      if (preview) break;
    }
    if (preview.length > MAX_BODY) preview = `${preview.slice(0, MAX_BODY).trimEnd()}…`;

    const summary = `pi · ${basename(ctx.cwd ?? process.cwd())}`;
    try {
      await pi.exec("notify", ["send", "--name", "pi", summary, preview || "Finished"], {
        timeout: 5000,
      });
    } catch {
      // A missing CLI or an unreachable hub must never break the session.
    }
  });
}
