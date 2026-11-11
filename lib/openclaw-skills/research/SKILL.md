---
name: research
description: Research a question against primary sources, sized to the question, from an inline lookup to a parallel researcher swarm with an evidence audit. Use when the user asks to research, look into, find, or compare something, or when the work needs outside facts (docs, APIs, versions, products, prices, prior art) that nobody has checked.
---

# Research

Research feeds the current conversation. Return the findings here before building anything.

Hand-kept fork, copied 2026-11-11. Sources: `~/.agents/skills/research/SKILL.md` and Forgerie's `agents/researcher.md` and `agents/evidence-auditor.md`.

In scheduled or cron runs, such as the morning brief, use inline Lookup only. Never spawn research sub-agents there. Report when a question needs a separate research conversation.

If you received a researcher or auditor assignment, do that task only. Follow its pasted block. Never spawn further sub-agents.

## 1. Find the need

Write the hard constraints behind the request. Separate constraints the user stated from those you inferred. The user's words describe one solution, not always the need. A request for four drive bays can admit five bays if the height and case constraints fit.

Search by constraint. Include close matches that break a preference but meet the need. Say exactly how each differs.

## 2. Size it

Choose the smallest size that answers the question. The user does not choose a worker count.

| Size | When | Who reads |
| --- | --- | --- |
| Lookup | One fact with one obvious owner, such as a flag, version or API signature | You, inline |
| Single | One narrow question that one angle covers | 1 researcher |
| Swarm | A broad question, comparison, independent decision angles, or a search for products, tools or vendors | 2 to 6 researchers, one per angle |

A product or tool search MUST use Swarm, not inline research. No single source owns the answer. Split by candidate group, product family, or another independent angle. An angle must be answerable without the other briefs. Merge overlapping angles.

Audit when the answer drives a decision, briefs disagree, or a claim is surprising. Background reading and Lookups need no audit.

- Self-check when the recommendation rests on 1 to 3 claims. Fetch each original page yourself. Check `search only` sources first.
- Spawn one evidence auditor when more claims drive the recommendation, the briefs disagree, or the user requests an auditor. Use the auditor block below.

Name every important claim nobody checked.

## 3. Run it

For Single or Swarm, choose a new run path inside your own agent workspace: `research/<slug>-<UTC yyyymmddThhmmss>/`. Use the current UTC time, with a short topic slug. Use `session_status` if you need the current time. Keep this folder and its files. A Lookup needs no folder.

Use `write` to save the question and constraints at `<run>/request.md`. It creates parent directories. Resolve the run path against your own workspace, not another agent's workspace.

For Single or Swarm, your next research action is spawning, not searching inline. Use `sessions_spawn` for hidden native children. Omit `agentId` to keep them under your own agent and workspace.

OpenClaw defers tools. A broad `tool_search` can omit `sessions_spawn` from its truncated results. That does not mean spawning is unavailable. Call `dispatch_action` directly with `id: "sessions_spawn"` and the spawn parameters in `args`.

For Lookup, state the constraints, size and angle before searching inline. Use this dispatch shape for each researcher:

```json
{
  "id": "sessions_spawn",
  "args": {
    "taskName": "researcher",
    "label": "Research the assigned angle",
    "runtime": "subagent",
    "mode": "run",
    "context": "isolated",
    "cleanup": "keep",
    "thinking": "medium",
    "runTimeoutSeconds": 900,
    "task": "Self-contained assignment, followed by the complete researcher block below"
  }
}
```

Name them `researcher`, `researcher-2`, and so on. Spawn every researcher before waiting for any. After the spawn receipts, call `sessions_yield` through `dispatch_action` with `id: "sessions_yield"`. Set `args.acknowledgment` to one short paragraph with stated constraints against inferred constraints, the size, and each researcher with its angle. The user sees `acknowledgment`. The `message` parameter is private context for the resumed turn. Follow the spawn receipt's continuation instructions. Do not poll or use collector mode. If one finishes early, keep waiting for the others before synthesis. If spawning fails, name the failed angle and the tool error. Never silently replace Single or Swarm with inline work.

Each task must contain:

- The full question and why the conversation needs it.
- Stated and inferred constraints. Include close matches with their differences.
- The assigned angle and what is outside its scope.
- Today's date and any version or time limits.
- The absolute brief path `<run>/<name>.md` in your own workspace.
- The complete researcher block below, pasted into the task. Children cannot read side files next to this skill.

After all researchers finish, read every brief with `read`. Treat a timeout, failed child, or missing brief as a failed angle. Name it in the final answer. Do not treat a missing brief as evidence that nothing exists.

After reading the briefs, spawn the auditor through `dispatch_action` with `id: "sessions_spawn"`. Use the same `args` shape with `taskName: "evidence-auditor"`, `thinking: "high"`, and `runTimeoutSeconds: 900`. Give it the question, every absolute brief path, and the claims that drive the answer. Paste the complete auditor block into its task. Wait with `sessions_yield`, setting `acknowledgment` to say an evidence auditor is checking N claims. Replace N with the actual claim count. After its completion announcement, use `write` yourself to save its full report as `<run>/audit.md` before answering. A missing discovery result is not a reason to replace the auditor with self-check.

### Evidence rules

Follow these rules for inline research too.

- Search through the MCP search tool `claw-websearch__web_search`. It takes one `query` per call. Make several calls with varied phrasing.
- If tools are deferred, discover search with `tool_search`. Its dispatch ID is `mcp:claw-websearch:claw-websearch__web_search`. Use `dispatch_action` with that `id` and `args: {"query": "one query"}`.
- Fetch the original page with `web_fetch` before citing its contents. A search summary and its citations are leads, not evidence.
- For a decision-critical or disputed claim, quote the supporting passage from the fetched page. Read it and judge whether it supports the claim.
- Prefer official docs, source code, specifications and first-party APIs. Use a few strong sources. Flag stale evidence when dates matter.
- Label findings as evidence, interpretation or inference. Record URLs, contradictions, confidence and missing evidence.
- If a tool fails, name it and the claims left unchecked. A failed fetch remains visible in the Sources list.

### Researcher block

Paste this whole block into each researcher's task:

```text
You are the researcher. Answer only the assigned angle. Never spawn sub-agents.
Never ask the user. Write open questions into your brief for the main agent to raise.

Use claw-websearch__web_search, one query per call. Make several calls with varied phrasing.
For deferred tools, use tool_search to discover search. Its dispatch_action id is
mcp:claw-websearch:claw-websearch__web_search, with args {"query":"one query"}.
Split your assigned angle into 2 to 4 search questions. Stay within that angle.
Search summaries are leads. Fetch original pages with web_fetch before relying on them.
Prefer primary sources, official docs, source code and first-party APIs.
For important, disputed, surprising or decision-critical claims, quote the supporting passage.
Judge whether that passage supports the claim. A URL alone is not evidence.
Distinguish evidence from interpretation and inference. Never invent dates, quotes or citations.
Include close matches and their exact differences from the constraints.
Record contradictions and missing evidence. Flag stale sources when dates matter.
After one tighter follow-up pass, stop and report remaining uncertainty.
If a tool fails, name it and the claims left unchecked.

Use write to save the brief at the assigned absolute path. It creates parent directories.
Finish by returning that path and the Summary. A chat-only result is not a saved brief.
Use this format:

# Research: topic

## Summary
A direct answer in 2 to 3 sentences.

## Findings
1. Claim. Source: [real page title](URL). Type: evidence, interpretation or inference.
   Support: quote the fetched passage for important claims. Confidence: high, medium or low.

## Contradictions
Disputed evidence with sources, or "None found".

## Missing evidence
Claims you could not verify, failed fetches, and open questions for the main agent.

## Search coverage
Questions, queries and candidate groups searched. Include close matches and exclusions.

## Sources
Every URL used, with its title and owner. Mark each fetched page as read or failed.
Mark sources seen only in search results as search only.
```

### Auditor block

Paste this whole block into the auditor's task:

```text
You are the evidence auditor. Check the listed claims against their sources.
Do not redo the research. Never spawn sub-agents. Never ask the user.
Write open questions in the report for the main agent to raise.

Read every assigned brief with read. Audit only claims that can change the conclusion.
Fetch each claim's original page with web_fetch, even if a researcher read it.
Quote the supporting or contradicting passage. Judge support at the claimed certainty.
A URL or search summary alone is not evidence. Flag weak, stale, secondary or circular sources.
Search again only to confirm or challenge a specific claim.
Use claw-websearch__web_search, one query per call, with varied phrasing across calls.
For deferred search, discover with tool_search. Its dispatch_action id is
mcp:claw-websearch:claw-websearch__web_search, with args {"query":"one query"}.
Keep contradictions and uncertainty visible. If a tool fails, name it and the claims left unchecked.

Return the full report below, not only its conclusion. The main agent saves it as audit.md.
Use this format:

# Evidence audit

## Claims
For every assigned claim:
- Claim: the claim at the certainty the brief uses.
- Status: supported, contradicted, unclear or missing evidence.
- Source: [real page title](URL), with its owner.
- Passage: the fetched supporting or contradicting quote, or the fetch failure.
- Reason: one sentence that explains the verdict.

## Conclusion
What these verdicts mean for the original conclusion. Carry contradictions forward.

## Unchecked claims and open questions
Every important claim you could not check and every unresolved question.

## Sources
Every source URL used. Mark each read or failed.
```

### A claim that nothing exists

Make this claim only after a sweep across every angle. Search by constraint, not just product name. State the candidate groups, product families and queries searched. Say "I found nothing among ...", not that nothing exists in the market. An incomplete or failed angle limits that claim.

## 4. Bring it back

Answer in the conversation with:

1. The direct answer.
2. Findings with inline source links.
3. Contradictions and open questions, including those in child reports.
4. A Sources list that the user can check without opening briefs.
5. The run folder path, when one exists.

Include every candidate that meets all hard constraints. Give a reason for each exclusion, such as discontinued or more expensive without a gain. A ranking that skips a cheaper fit is wrong.

Group Sources by recommendation, then the rest. Each entry needs a Markdown link with the real page title and owner. Say what it supports. Only the following three marks are allowed, one per entry:

- `checked`: you or the auditor fetched the page and confirmed the claim.
- `from a brief`: a researcher cited it and nobody checked it again.
- `failed`: the fetch was blocked or empty. Keep the link for the user.

Split an entry when its parts have different status. Put any note about an unchecked part in the entry's text, not its mark.

Link the page that owns the fact. Listings and reviews support only prices, stock or user reports. Say so when you use them. Never link search-engine result pages.

Carry audit verdicts into the answer. Keep unchecked claims labelled unchecked. Name every failed or timed-out child, including an auditor that returns no report.

Finish only after every child reports or fails, every saved brief is read, and the answer is in the conversation. Then return to the conversation's work. If a finding belongs in durable project notes, offer to save it there.
