---
name: web-search
description: Search the web for current information, releases, facts and sources. Use when the user asks to search the web or requests current information that needs a source.
---

# Web search

Web search IS connected here through the account's registered MCP server `claw-websearch`. The disabled built-in `web_search` adapter is not the search route. Its missing provider configuration does not mean this MCP search is unavailable.

Use `dispatch_action` with `id: "mcp:claw-websearch:claw-websearch__web_search"` and `args: {"query": "the user's search question"}`. Use `tool_search` or `tool_describe` when you need its schema. Search first, then use `web_fetch` to check the original sources before citing their contents. Search snippets are leads, not fetched-page evidence. If the MCP call fails, report the exact failure instead of claiming search is not configured or inventing a result. Do not substitute an outside search service or a new credential.

For a broader research task, follow the shared `research` skill's sizing and evidence rules.
