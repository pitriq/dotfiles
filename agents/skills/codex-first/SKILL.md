---
name: codex-first
description: "Route implementation work to Codex CLI; Claude specs, reviews, verifies."
---

# Codex First

Claude Code sessions only. Codex/other harnesses: skip; never self-delegate.

Rationale: Claude (Fable/Opus) tokens metered + expensive; Codex flat-rate. `gpt-5.6-sol` is usually the better and faster model at writing/implementing code; Claude wins at ergonomics - judgment, design, spec-writing, review, orchestration. So Codex types, Claude thinks and verifies.

## Route

Delegate to Codex (default for hands-on work):

- implementation from a frozen spec; refactors; mechanical migrations
- bug fixes with known repro; test writing; coverage fills
- CI fixes, dependency bumps, scripts/tooling
- bulk codebase exploration where raw reading >> the answer

Keep in Claude:

- design, API design, architecture, naming, UX judgment
- tasks where writing the spec IS the work (ambiguity = design)
- tiny edits (~<20 lines, single obvious change) - delegation overhead loses
- anything needing session tools: MCP (browser/computer-use/chronicle), 1Password, secrets
- destructive/irreversible ops, releases, pushes, GitHub mutations - Claude-side per git rules
- review of Codex output - never delegated, never skipped

Mixed task: Claude designs first, freezes spec, delegates build-out.
Heuristic: prompt reads as a work order -> delegate; writing it forces decisions -> design, Claude.
Portfolio/multi-repo work: `$maintainer-orchestrator` instead.

## Invoke

Always through the `codex-runner` subagent (Sonnet shell that owns the codex CLI mechanics) — never run `codex` via Bash in the main session, foreground or background:

- standalone: Agent tool, `subagent_type: codex-runner`, prompt = the full spec (contract below)
- in a Workflow script: `agent(spec, {agentType: 'codex-runner'})`
- model, tools, and codex invocation details live in the agent definition; don't pass a model override
- parallel independent tasks: one runner each, separate repos/dirs
- follow-up fixes: SendMessage to the same runner — it resumes the codex session, keeping context; cheaper than fresh spawns
- `--yolo` (approvals off) only when the sandbox blocks the task (writes outside the repo, sandbox-hostile tooling), and only if the user named approvals-off in their message — otherwise stop and ask them first. Once authorized, state it explicitly in the runner prompt; the runner won't escalate on its own.

## Prompt contract

Codex starts with zero session context. Every prompt: goal, exact repo/paths, constraints, non-goals, proof expected (exact test command), output shape ("report files changed + test output"). Spec quality decides success.

## Verify (Claude, always)

- `git status -sb` + read the full diff; judge like a contributor PR
- run focused tests yourself or demand proof output; Codex claims are advisory
- iterate by messaging the runner; after 2 failed rounds, take over and do it directly
- normal closeout still applies: `$autoreview` before ship

## Economics

Win = generation + exploration tokens moved to Codex; Claude spends only on spec + diff review. Don't ping-pong trivia through delegation; don't re-read what Codex already summarized.
