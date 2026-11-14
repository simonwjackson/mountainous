---
name: pace
description: Check household savings goals and Budgets. Use for “how are we doing?”, “are we ahead or behind?” and questions about whether our goals or Budgets are on track.
---

# Pace

Call `dispatch_action` with `id: "mcp:pace:pace__pace_status"` and `args: {}`. Use `tool_search` or `tool_describe` if needed. Answer with the tool's short text; its Status card shows itself. Never invent or recompute figures. If the call fails, report the failure without substituting figures.
