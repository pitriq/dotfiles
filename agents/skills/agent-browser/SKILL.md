---
name: agent-browser
description: "Browser automation CLI for AI agents, installed with Homebrew and run as agent-browser. Use when the user needs to interact with websites: opening pages, clicking, filling forms, taking screenshots, scraping data, testing web apps, logging into sites, exploratory QA, dogfooding, bug hunts, or any browser debugging task. Prefer this over built-in browser automation for interactive web work."
---

# agent-browser

Use [agent-browser](https://github.com/vercel-labs/agent-browser) for browser automation and web app debugging. It is installed with Homebrew (`brew install agent-browser`), so call the `agent-browser` binary directly. Its Chrome for Testing download (`agent-browser install`) is already done.

agent-browser drives Chrome/Chromium through CDP and exposes compact accessibility-tree element refs for reliable interaction.

## Start here

This file is a discovery stub, not the full usage guide. Before running browser automation commands, load the version-matched workflow from the CLI:

```sh
agent-browser skills get core
agent-browser skills get core --full
```

Use the first command for workflows, common patterns, and troubleshooting. Use `--full` when you need the complete command reference or templates.

## Specialized skills

Load a specialized skill when the task is not ordinary browser web-page automation:

```sh
agent-browser skills get electron
agent-browser skills get slack
agent-browser skills get dogfood
agent-browser skills get vercel-sandbox
agent-browser skills get agentcore
agent-browser skills list
```

- `electron`: Electron desktop apps such as VS Code, Slack, Discord, Figma, Notion, and Spotify.
- `slack`: Slack workspace automation.
- `dogfood`: Exploratory testing, QA, and bug hunts.
- `vercel-sandbox`: Browser automation inside Vercel Sandbox microVMs.
- `agentcore`: AWS Bedrock AgentCore cloud browsers.

## Rules

- Use `agent-browser ...` for every command in this skill.
- If `agent-browser` is not on PATH, ask the user to run `brew install agent-browser` and then `agent-browser install`. Do not fall back to `npx agent-browser`: inside a large repo it takes 15 s or more per call.
- Do not run `agent-browser upgrade`, `agent-browser install`, or `npm i -g agent-browser` unless the user explicitly asks. Homebrew owns updates.
- Prefer the CLI-provided skill content over guessing commands from memory.
- When the user needs to inspect or debug a mobile app in an Apple Simulator, use the `serve-sim` skill instead.
