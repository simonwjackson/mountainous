---
name: tasks
description: Capture and manage Simon's GTD tasks, inbox, projects and areas in Mindwtr.
---

# Tasks

Mindwtr is Simon's GTD system. Use the `mindwtr` MCP tools. This skill is for Simon only.

- Capture a request with `mindwtr_add_task`, `status: "inbox"`. Keep Simon's words. Do not turn a capture into a project or add dates, priority or context he did not give.
- For “what should I do?”, call `mindwtr_list_tasks` with `view: "available"`. This respects deferred starts and sequential project blockers. Do not substitute all open tasks. Use `view: "deferred"` or `"blocked"` only when explaining those lists.
- For his inbox, list tasks with `status: "inbox"`. Explain that inbox captures need clarification; they are not all next actions.
- Read projects and areas before assigning them. Tell Simon before making a new project; do not invent projects silently.
- Confirm the exact task, project or area before any delete. `mindwtr_delete_task`, `mindwtr_delete_project` and `mindwtr_delete_area` delete data. A project delete can affect its tasks.
- A write can succeed even if its response times out. Read back before retrying. Do not claim a change succeeded without a result or a read-back.

Do not change the wind-down or coach workflows.
