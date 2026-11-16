---
name: pace
description: Check household savings goals and Budgets, change goals, Budgets and Categories, and Undo Changes. Use for “how are we doing?”, “are we ahead or behind?” and changes to household plans.
---

# Pace

For “how are we doing?” or whether goals and Budgets are on track, call `pace_status` with `{}`. Call `dispatch_action` with `id: "mcp:pace:pace__pace_status"` and `args: {}`. Use `tool_search` or `tool_describe` if needed.

When asked to see the goals, Budgets or Overview, call `pace_overview`. Never draw your own widget, chart or table from Pace figures. The Status card and Change card show themselves under the answer. Do not repeat their rows or make a table of them.

Simon and Laure can make the same reversible Changes:
- `pace_goal_set`: change a Savings goal's target and/or due month.
- `pace_goal_add`: add a named Savings goal with its target and due month.
- `pace_goal_remove`: remove a Savings goal.
- `pace_goal_paid`: confirm a goal was paid; it leaves Goal order.
- `pace_budget_set`: set or change an existing Category's monthly Budget.
- `pace_budget_remove`: remove a Budget.
- `pace_category_correct`: correct a transaction's Category. Use a merchant Rule by default; use scope `this` only when asked for that transaction alone. If the tool reports ambiguous matches, ask which candidate; do not guess.
- `pace_category_one_off`: mark or unmark a Category as one-off in Recent pace.
- `pace_changes`: read recent Changes and whether each can be undone.
- `pace_undo`: Undo a Change by id, or omit the id for the caller's latest undoable Change. “Undo that” works by talking even after the card is gone. Use `pace_changes` if a specific earlier Change needs its id. Undo can itself be undone under the same rule.

After a write, confirm in one sentence from the tool's short text, say who changed what, and offer Undo. Keep the server's figures and wording. If the Change card can no longer Undo, the person can still say “undo that”. If the tool refuses Undo because someone changed the same item later, explain the tool's reason; never overwrite their later Change to force an Undo.

Never invent or recompute figures. If a call fails, say so. Do not substitute figures. Changes never send Alerts. Pace has no separate website or editor; use the tools here.

Pace already shares cash and Recent pace across goals by due month, earliest first, on its own. If asked to redistribute by deadline, say so and call `pace_status` to show the result.
