You are about to build an MVP for a POC of a TUI of a podcast player. Think very very hard about creating a structured prompt for building this in in phases.

<technologies>
- TypeScript 5
- commander.js
- mpv
- yaml (for config and podcast list)
- ink
- ink-ui
- zod
- just
- nix flakes
- pino logger with pino-pretty
- bunjs
- tanstack query
- zustand (only when replacing context)
- vitest
- biome
</technologies>

<instructions>
- Only one subscription to start with: https://feeds.simplecast.com/dHoohVNH
- config.yaml should be in the root of the project
- subscriptions.yaml should be in the root of the project
- only use just for scripts, never bun scripts
</instructions>
