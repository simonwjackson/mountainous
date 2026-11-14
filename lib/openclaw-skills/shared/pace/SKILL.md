---
name: pace
description: Check household savings goals and Budgets. Use for “how are we doing?”, “are we ahead or behind?” and questions about whether our goals or Budgets are on track.
---

# Pace

Call `dispatch_action` with `id: "mcp:pace:pace__pace_status"` and `args: {}`. Use `tool_search` or `tool_describe` if needed.

Answer in one or two sentences, from the tool's short text. The Status card shows itself under the answer. Do not repeat its rows or figures, or make a table of them.

Never invent or recompute figures. If the call fails, say so. Do not substitute figures.

Pace has no app or website. Changing goals, Budgets, categories or the order of goals is not available yet. Say that plainly. Do not send the person anywhere else to make the change.
