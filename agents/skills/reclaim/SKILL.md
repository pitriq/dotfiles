---
name: reclaim
description: "Free disk space on this Mac: scan everything that can be cleaned up (stale worktrees and their databases, simulators, emulators, Xcode and Android leftovers, Docker, package caches, toolchains), decide what should go using the user's standing rules, ask only about real judgment calls, show a short verified plan, and have agents run it after one go.\nTRIGGER when the user invokes /reclaim or asks what they can clean up or how to free disk space. Do not trigger for deleting one specific known file."
---

# Reclaim

Scan, decide, ask only what you can't decide, verify, and run on one go. The user should read one short plan and answer a handful of questions, not pick items from a long list.

`/reclaim` covers every area. `/reclaim docker apple` (or any area name from `areas.md`) covers only those.

## Rules

- Until the go in step 5, everything is read-only. Allowed: `du`, `find`, `stat`, `ls`, `lsof`, `ps`, `git worktree list`, `git status`, `git log`, `gh pr list`, `docker ... ls`, `docker system df`, `docker inspect`, `psql` SELECTs, `xcrun simctl list`, `avdmanager list`, `supacode worktree list`, `scan-workspaces.py`, and dry-run flags (`brew cleanup -n`).
- Files go to `trash`, never `rm`. State a tool owns is removed with that tool (`docker volume rm`, `xcrun simctl delete`, `DROP DATABASE`, `sdkmanager --uninstall`, `cargo clean`, `brew cleanup`), because trashing its files leaves the tool's records broken.
- Nothing in the off-limits list at the end of `areas.md` is ever planned, asked about, or listed except as keep.
- Keep slow commands bounded: `du -k -d 1` on known roots (macOS `du` rejects `-s` with `-d`), a `timeout` on anything that walks a large tree, no scans of `/`.
- A path you can't read is reported once with its fix (usually Full Disk Access for the terminal app), never dropped.

## 1. Baseline

Record free space on `/System/Volumes/Data` and the date. Read `~/.local/state/reclaim/decisions.md` (the user's past answers about specific items) and the newest report in `~/.local/state/reclaim/`.

## 2. Scan with a panel

Run one scanner per area in `areas.md`, all at once. In T3, use `delegate_task` with `claudeAgent/claude-sonnet-5-5` and `effort=high`. Outside T3, use the harness's subagents. With neither, scan the areas yourself.

Each brief gives the absolute paths of this file and `areas.md`, the area letter, the paths other areas own, and the matching lines of `decisions.md`. It tells the scanner to change nothing, start no subagents, and return one table, `id | item | path or object | GB | proposal | evidence | command | what you lose | precondition`, where `proposal` is `clean`, `ask`, or `keep` under the defaults below, and `precondition` is what must hold at run time (an app quit, a process stopped, no connections). Plus unreadable paths and failed commands.

## 3. Decide

Merge the tables, counting nested paths once. Re-run the evidence for every `clean` item of 1 GB or more yourself, and turn it into `ask` if it doesn't hold. Apply these defaults, then `decisions.md`, which wins over them.

Clean without asking:

- Regenerable caches and build output: package manager caches, DerivedData, Gradle caches, CocoaPods, Docker build cache, simulator dyld caches, Git-ignored build folders in repos idle for 30 days, and a Rust target dir even when active.
- Worktrees that are clean with nothing unpushed, whatever their PR state (the branch is on the remote), together with their DB, companion DBs, and symlinks. A dev stack running in one is stopped first; that goes in the plan as a precondition, not a question.
- Orphan workspace databases with no owning worktree, and stopped containers and images nothing uses.
- Simulators and AVDs unused for 30 days, SDK, NDK, and runtime versions nothing references, and a runtime once no device with app data uses it.
- Old copies when a newer one of the same thing is kept: superseded snapshots, backup files, old releases.
- Caches of a running app, with "quit X first" as the precondition. The executor skips the item if the app is still running.
- A package store an older tool major still uses is pruned with that tool (`pnpm store prune`), not deleted.

Ask:

- A worktree with uncommitted or untracked work. Offer to copy untracked files to `~/Downloads/<worktree>-files/` first.
- The newest snapshot, dump, or data directory of its kind, and anything whose owner you couldn't identify.
- History and app data: chat logs, offline data, transcripts.
- Anything 20 GB or more that isn't a cache.

Keep: what's in use and the off-limits list.

## 4. Plan

Write `~/.local/state/reclaim/<YYYY-MM-DD>.md` with every item and its evidence, for reference. The chat gets a short plan instead:

1. One line: free space now, and after the plan.
2. **Cleaning**, grouped by kind, one row per group: what it is, how many items, GB, and how the space comes back (right away, after OrbStack's disk image shrinks, or after emptying Trash). Name the largest items inside each group.
3. **Leaving alone**, in one line: the total kept and the three largest reasons.
4. The questions, asked with `AskUserQuestion` (up to four questions of up to four options each; group similar items into one multi-select question). Mark your guess as the recommended option. With no question tool, list them numbered with your guess.

## 5. Verify, then go

After the answers, re-run every planned item's evidence and precondition now, since things changed while the user read. Show the result as one table, `item | GB | checked | ok`, with checks in a few words ("PR #10591 merged, clean, 0 unpushed", "no AVD uses it", "Chrome running, will skip"). Drop items that failed and say why. End with the total and one question: go?

Save the user's answers to `decisions.md` as one line per item or rule (`path or pattern: keep|clean, reason, date`). When an answer states a general preference ("don't touch X"), also add it to the off-limits list in `areas.md`.

## 6. Run with agents

On go, split the plan into two executors that run at once: one for tool-owned state (worktrees, databases, Docker, toolchains, simulators, SDKs) and one for trashing files. In T3, use `delegate_task` with `claudeAgent/claude-opus-5-5` and `effort=high`. Each brief lists its items in order with exact paths, commands, and preconditions, and tells it to check each precondition right before acting, skip and report what no longer holds, never use `rm`, never empty Trash, and never quit the user's apps.

Worktrees:

- **Supacode worktrees** (`/Applications/supacode.app/Contents/Resources/bin/supacode worktree list` shows them): run `supacode worktree stop -w <id> --background`, then `supacode worktree delete -w <id> --background`. Delete runs the repo's delete hook (TrashLab's `scripts/supacode/delete.sh` drops the workspace DB), removes the folder outright, and deletes the local branch. The hook skips the drop without failing when Postgres is unreachable, and leaves companion DBs (`<db>_console`) and symlinks, so check and remove those after.
- **Other worktrees:** unlock if locked, trash symlinks that point at it, trash the folder, then `git -C <repo> worktree prune --expire now`. The branch stays.
- **Databases:** dropped with `docker exec <container> psql -U postgres -c 'DROP DATABASE "<name>";'`.

## 7. Close out

Review both executors' reports yourself. Report the space freed so far and what is waiting (Trash, OrbStack shrinking), what was skipped and why, and any failures with their output. Then ask whether to empty Trash, as its own question, since it can't be undone. Append the outcome to the report file.

Name the scanners and executors that ran, any that were swapped, and any that were skipped.
