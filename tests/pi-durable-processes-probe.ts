// Offline CLI acceptance probe. No model request and no managed command is launched.
import { access } from "node:fs/promises";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    const tools = pi.getAllTools().filter(tool => tool.name === "process");
    if (tools.length !== 1) throw new Error(`Expected one process tool, found ${tools.length}`);
    const state = process.env["PI_DURABLE_PROCESSES_STATE_DIR"];
    if (state === undefined) throw new Error("Probe needs an isolated process state directory");
    await access(join(state, "managed-processes", `${ctx.sessionManager.getSessionId()}.lock`));
    process.stdout.write("DURABLE_PROCESS_TOOL_READY\n");
    ctx.shutdown();
  });
}
