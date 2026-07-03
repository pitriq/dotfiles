---
name: agent-browser
description: "Browser automation CLI for AI agents, run without global installation via npx agent-browser. Use when the user needs to interact with websites: opening pages, clicking, filling forms, taking screenshots, scraping data, testing web apps, logging into sites, exploratory QA, dogfooding, bug hunts, or any browser debugging task. Prefer this over built-in browser automation for interactive web work."
---

# agent-browser

Use [agent-browser](https://github.com/vercel-labs/agent-browser) for browser automation and web app debugging. Run it through `npx agent-browser`; do not assume a global install, and do not run `npm i -g agent-browser` or `agent-browser install` unless the user explicitly asks.

agent-browser drives Chrome/Chromium through CDP and exposes compact accessibility-tree element refs for reliable interaction.

## Start here

This file is a discovery stub, not the full usage guide. Before running browser automation commands, load the version-matched workflow from the CLI:

```sh
npx agent-browser skills get core
npx agent-browser skills get core --full
```

Use the first command for workflows, common patterns, and troubleshooting. Use `--full` when you need the complete command reference or templates.

## Specialized skills

Load a specialized skill when the task is not ordinary browser web-page automation:

```sh
npx agent-browser skills get electron
npx agent-browser skills get slack
npx agent-browser skills get dogfood
npx agent-browser skills get vercel-sandbox
npx agent-browser skills get agentcore
npx agent-browser skills list
```

- `electron`: Electron desktop apps such as VS Code, Slack, Discord, Figma, Notion, and Spotify.
- `slack`: Slack workspace automation.
- `dogfood`: Exploratory testing, QA, and bug hunts.
- `vercel-sandbox`: Browser automation inside Vercel Sandbox microVMs.
- `agentcore`: AWS Bedrock AgentCore cloud browsers.

## Rules

- Use `npx agent-browser ...` for every command in this skill.
- Do not install or update agent-browser globally unless the user explicitly asks.
- Prefer the CLI-provided skill content over guessing commands from memory.
- When the user needs to inspect or debug a mobile app in an Apple Simulator, use the `serve-sim` skill instead.
