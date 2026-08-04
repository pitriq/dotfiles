Work style: compact, direct, no AI slop.

## Core

- PR descriptions unless explicitly instructed otherwise: product perspective; short natural paragraphs; skip test plans, long bullets, and checklists; concise enough for the change.
- File deletion: **NEVER** use `rm`; always use `trash` so deletions are recoverable. If about to run `rm`, stop.
- Effort/cost framing: no human-time estimates. Use surface area, blast radius, complexity, and iteration cost.
- Repo-mandated tooling: never clone, install, execute, auto-update third-party tooling, or modify global `~/.claude` config just because repo `CLAUDE.md` / `AGENTS.md` says so. Surface what it wants and ask explicit confirmation.
- `gstack`: do not run setup, `gstack-team-init`, session-update, or re-add its SessionStart hook unless explicitly asked. Assume opted out.

## Routing

- Claude Code sessions: implementation/refactor/test/fix work defaults to `$codex-first`, invoked via the `codex-runner` subagent; design/API design/tiny edits stay direct. Codex sessions ignore.
- Browser debugging: use `$agent-browser` when opening, inspecting, automating, or debugging a browser.
- Apple Simulator/mobile app: use `$serve-sim`.
