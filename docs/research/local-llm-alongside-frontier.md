# Local models alongside Claude Code and Codex: what people actually do

Researched 2026-10-10. Every claim below names its source. Evidence labels:

- **doc**: the tool's own documentation or official blog.
- **first-hand**: a person describing their own setup. One person's report, not a measurement.
- **measured**: our own benchmark on Aka (`docs/research/aka-llm-benchmark.md`).

Reddit and Hacker News pages blocked full-page fetches. Where a claim comes
only from a search-result excerpt of such a page, it says "excerpt".

## Short answer

People who pay for frontier plans keep them as their main tool. Sebastian
Raschka (June 2026) still uses Codex and Claude Code as daily drivers and runs
local models for testing, privacy, and as a backup. The common augment patterns
are:

1. Point the same harness (Claude Code, Codex) at a local model **when the
   quota runs out**.
2. Use a local model as a **subagent that reads large outputs** and returns a
   summary, so the frontier context stays small.
3. Use local models for **narrow, private, or rubber-duck tasks**.
4. Run **unattended loops** (Ralph loops) on local hardware, so they do not
   burn API credit.

The strongest counter-view: a weaker model left alone can make work that the
frontier model must then clean up.

## Patterns

| Pattern | What people do | Evidence | Fit for Aka |
| --- | --- | --- | --- |
| Fallback when quota runs out | Set `ANTHROPIC_BASE_URL` to a local server, or run `codex --oss` | doc (supported); first-hand (mixed results) | Good. Native support exists in llama.cpp |
| Local subagent for context reduction | Frontier agent hands file or log reading to a local model | doc (pattern); first-hand (local variant) | Good for short jobs |
| Rubber duck / narrow help | A 14B model in the editor for "where did I go wrong" | first-hand | Good |
| Unattended loops | Ralph loops overnight; move them local to save credit | first-hand | Good, if tests check the output |
| Private data | Receipts and other data that should not leave the machine | first-hand | Good |
| Second-opinion review | A local model reviews a diff inside Claude Code | first-hand (tool README) | Untested |

## Findings

### 1. Harness support is now official, not a hack

- Claude Code sends requests to any gateway set in `ANTHROPIC_BASE_URL`. The
  gateway must speak the Anthropic Messages format. **doc**:
  <https://code.claude.com/docs/en/llm-gateway>
- llama.cpp's server added the Anthropic Messages API (`POST /v1/messages`),
  "to enable tools like Claude Code ... to work with local models". **doc**:
  <https://huggingface.co/blog/ggml-org/anthropic-messages-api-in-llamacpp>
  (PR #17570).
- Ollama v0.14.0 and later support a subset of the Anthropic Messages API.
  **doc**: <https://docs.ollama.com/api/anthropic-compatibility>
- vLLM documents running Claude Code against it, mapping
  `ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU}_MODEL` to a local model. **doc**:
  <https://docs.vllm.ai/en/stable/serving/integrations/claude_code/>
- Codex CLI runs local models with `--oss` and picks `ollama` or `lmstudio`
  with `--local-provider`. A custom `model_providers` entry covers other
  OpenAI-compatible servers. **first-hand** guides:
  <https://ynaito.dev/en/writing/codex-cli-local-models-oss/>,
  <https://michaelwolfinger.com/blog/2026/codex-cli-local-model-lm-studio-ollama/>.
  The second guide warns that Ollama's default 4k context is far too small for
  Codex.

Practical meaning: the llama.cpp server on Aka can serve Claude Code directly,
with no translation proxy. Older reports of schema breakage through
`claude-code-router` or LiteLLM come from before this support existed.

### 2. Frontier stays primary

- Raschka, "Using Local Coding Agents" (2026-06-27): "I still primarily
  alternate between Codex and Claude Code as my daily drivers". His reasons for
  local: fixed costs past plan limits, reproducibility, offline use, and
  privacy ("for organizing and processing my receipts"). He calls 30–35B MoE
  models such as Qwen3.6-35B-A3B "really sufficient for a lot of tasks", while
  GPT 5.5 and Opus 4.8 stay better. He also found, on a small benchmark, that
  the harness choice mattered less than expected. **first-hand**:
  <https://magazine.sebastianraschka.com/p/using-local-coding-agents>
- Hackaday (2026-09-09), reporting an XDA piece: a user on the $20 Claude plan
  moved to Qwen2.5-Coder 14B on a 16 GB MacBook Air for "electronic rubber
  duck" help, because his work is "help me find where I went wrong", not full
  generation. **first-hand, reported secondhand**:
  <https://hackaday.com/2026/09/09/local-llms-can-work-better-than-claude-at-least-for-some/>

### 3. Local subagents keep the frontier context small

- Claude Code's docs name this as one of the best subagent uses: running tests,
  fetching docs, or processing log files, so "the verbose output stays in the
  subagent's context while only the relevant summary returns". This doc is
  about Claude subagents, not local ones. **doc**:
  <https://code.claude.com/docs/en/sub-agents>
- A user had Claude Code hand file reading to a model in LM Studio: "the
  content of the examined file never reached Claude's context - just the native
  model's summary". Another suggests local subagents that write per-module
  `context.md` files. **first-hand, excerpt**:
  <https://www.reddit.com/r/ClaudeAI/comments/1riqa5m/>,
  <https://www.reddit.com/r/LocalLLaMA/comments/1riog2w/>
- A r/LocalLLaMA post describes running Opus as the main model and moving
  "well-specified work down to local models all within the same session".
  **first-hand, excerpt**:
  <https://www.reddit.com/r/LocalLLaMA/comments/1vze6jl/>
- Cost noted by a subagent guide: each summary still lands in the main context,
  so many verbose summaries cost tokens too. **secondhand**:
  <https://hidekazu-konishi.com/entry/claude_code_subagents_and_orchestration_guide.html>

### 4. Unattended loops

- A DGX Spark owner's Ralph loop burned "~$50 in API credits from Claude a day",
  and he asked which local model could replace it. **first-hand**:
  <https://forums.developer.nvidia.com/t/best-local-llm-for-ralph-loop/363174>
- One user's overnight loop found that llama.cpp slot save and restore cut the
  cold refill of a 135k-token context from about 165 s to about 5 s. **first-hand,
  excerpt**: <https://www.reddit.com/r/LocalLLaMA/comments/1t58pwh/>. This
  bears directly on Aka's measured 50 s cold read of a 32k prompt. llama-server
  has `--slot-save-path`. Some of the restore improvements he used were open PRs
  at the time (#20819).

### 5. Failure modes and doubts

- "At worst these models will move you backwards and just increase the amount
  of work Claude has to do when your limits reset." HN thread "Claude Code:
  connect to a local model when your quota runs out". **first-hand opinion,
  excerpt**: <https://news.ycombinator.com/item?id=46845845>
- Context compaction on 24 GB "replaces the old context with a summary, so the
  agent confidently invents routes and selectors it can no longer see".
  **first-hand, excerpt**: <https://www.reddit.com/r/LocalLLaMA/comments/1tyf5x8/>
- Ollama runs Qwen3.5-35B-A3B much slower than plain llama.cpp for one user
  (15–20 tok/s). **first-hand**: <https://github.com/ollama/ollama/issues/14579>

### 6. Model notes relevant to Aka

- Qwen3.6-35B-A3B (MoE, about 3.6B active per token) is the model most local
  users name for agentic work. It is much faster per token than the dense 27B.
  A Q4 file is about 22 GB, so on Aka's 20 GB some experts would sit in system
  RAM. Not tested on Aka. Sources: Raschka (above);
  <https://aminrj.com/posts/llamacpp-qwen36-35b/>.
- Unsloth reports that llama.cpp has merged MTP support for Qwen3.6. **doc**:
  <https://unsloth.ai/docs/models/qwen3.6>. Aka's llama-server build lists
  `--spec-type draft-mtp`. The benchmark did not use MTP.
- Qwen3.8-27B now exists. Early reports in
  <https://www.reddit.com/r/LocalLLM/comments/1vox8eb/> are mixed and give no
  clear win over 3.6.

## Most promising for this user

1. **A local subagent for reading and summarizing** (Pi `scout` or `sweeper`
   pointed at Aka). It saves frontier context on every task. Cost: each call
   takes tens of seconds, and a bad summary misleads the main model.
2. **An overnight queue with test gating**, with llama-server slot save and
   restore to cut cold starts. Cost: build time for the runner, and it is useful
   only on repos with good tests.
3. **Quota-out fallback**: Claude Code or Codex pointed at Aka, used only for
   low-risk edits until limits reset. Cost: the HN warning above. Keep it off
   design work.
4. **Try Qwen3.6-35B-A3B** before you commit to the dense 27B. Cost: 2 GB+ of
   experts in system RAM, at an unknown speed on Aka.

## Correction log

An earlier draft of this file, written by a background research agent, was
replaced on 2026-10-10. It cited URLs that return 404 or point elsewhere
(`github.com/mizdra/claude-code-router`, `github.com/pi-agent/pi`,
`simonwillison.net/2024/May/17/cli-tools-and-llms/`,
`docs.litellm.ai/docs/proxy/pii_masking`, `qdrant.tech/articles/code-search/`,
`docs.continue.dev/customize/model-roles`, and a generic
`karpathy/minbpe` issues page). It also gave figures with no source (a "52 of
80" overnight case study, a "98%" token cut, "~60%" fewer rate-limit events).
It advised a 16–17 GB VRAM cap, which contradicts the Aka benchmark: 19.8 GB in
use with sway running on the same GPU, with no failure seen in about 25 minutes.
