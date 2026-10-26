---
name: build
description: "Build a feature, fix, refactor, or migration end to end and on its own: set up a worktree if needed, size the work, settle the design with a plan arena, delegate the code, clean it up, prove it on the real app, check bigger changes for breakage and review them on three models, commit, and open and babysit the PR when asked.\nTRIGGER ONLY when the user explicitly invokes /build. Do not trigger for ordinary coding requests."
---

# Build

Take the request from idea to a proven, committed change, and decide the direction yourself. `AGENTS.md` has the models and delegation rules this file relies on. Stop for the user only when:

- the request leaves a product decision open,
- an action is outward-facing (push, PR, comments, anything sent to another service),
- a large run's frame raises a decision only the user can make (see Large).

When you stop, ask with the harness's question tool (`AskUserQuestion` in Claude Code, `request_user_input` in Codex), so the thread shows it is waiting. Put the context and your recommended option first. Decide everything else yourself, and list those decisions in the reply.

A fork you can settle by running something (behavior, layout, performance, what a library does) is not a product decision. Run a quick throwaway check and let the result decide.

Never ask whether to run an arena, a blast-radius check, or a review. This file decides. Skip any of them when the user says so.

Commit locally at each stage boundary: the repro, the implementation, the deslop pass, and each round of review fixes. Every review then covers `git diff <base>...HEAD`, new files included, where `<base>` is the remote branch this one merges into, such as `origin/main`, fetched first. A local `main` can be far behind. Pass that scope in each brief. Before the first commit, read the repo's commit hooks (`git config core.hooksPath`, else `.git/hooks`). If one pushes, stop and ask.

## 1. Get a workspace

The build runs in its own worktree on a `pitriq/<slug>` branch, and that worktree gets the full setup so the app can run: T3's project setup script if one is configured (T3 runs it), otherwise the repo's `supacode.json` `setupScript`.

- **In a worktree on a feature branch:** build here. If it was never set up (no dependencies, no env), set it up.
- **On the default branch in a T3 thread:** call `t3_worktree_handoff` as the last action of the turn, with branch `pitriq/<slug>`, `baseRef` from the repo's `supacode.json` `worktreeBaseRef` (else `origin/<default branch>`), and a `continuationPrompt` of "Read `<absolute path of this file>` and follow it for: <the original request>". The thread moves into the new worktree and continues there.
- **On the default branch outside T3:** create the worktree yourself, with the `supacode-cli` skill when Supacode is running, else with `git worktree add -b pitriq/<slug> <path> <base>`. Set it up and work there by absolute path.
- **Unrelated uncommitted work in the tree:** stop and ask.

## 2. Size it

Read the code the change touches. For an unfamiliar subsystem that spans many files, first send two to four read-only explorers on the default target, each on one part of it. Then pick a size from the whole change you plan, every file you expect to touch, and name it in the reply:

- **Medium** if the change touches any of these: a migration or the database schema, an export that another package, another app, or many callers use, a job or event, auth, money, feature flags, a stored or wire format, more than one package, or more than three files besides tests. Go to step 3.
- **Large** if it is too big for one plan, such as a backfill, several pieces that land separately, or a multi-hour run. See Large.
- **Small** if none of the above applies. Make the change yourself, commit it, run the deslop pass from step 4 unless the diff is a few lines, then go to step 5. If the diff ends up crossing a Medium trigger, say so in the reply.

**A bug** gets fixed from evidence. Reproduce it with `$verify` first. If it doesn't fire, make it fire: seed the data, log in as the affected user or tenant, tighten the conditions, or add instrumentation. Stop and report only when that fails. Find the cause by ruling out hypotheses with logging or instrumentation as the code runs, not by guessing. When two fixes fail on the same premise, test the premise. Every line that ships traces to that evidence, so a guard that "might help" does not ship, and anything a refuted hypothesis motivated gets reverted. Commit a failing test before the fix when the repo has a cheap test for that path. Otherwise the `$verify` artifact is the before.

**A refactor** changes structure, not behavior. Pin the current behavior first with a test or a before-and-after check, and keep it passing at every step. For code that deploys together, move every caller and delete the old API in the same change, with no compatibility shims or parallel paths. Anything a shipped client calls (the mobile apps, external consumers) or anything stored keeps working until there is evidence that nothing still depends on it. Keep the refactor only if the code is easier to read afterward. Otherwise revert it.

## 3. Settle the design

Write your own design first, then run `/arena` on it, text only, with your design entered as one candidate. Give every candidate `references/design-brief.md`, the grounding (what the code does now, with paths), and the constraints. Each candidate names the strongest shape it rejected and why, so you can trust it when the candidates converge. The judge's rubric includes `references/design-red-flags.md`, and so does your own read.

The result is the sketch: the caller's usage, the types, the signatures, and the module map. Show it to the user only when it holds a product decision.

## 4. Build against the sketch

Delegate to one implementation child in the current checkout, on the default target or the bugs and hard problems target. Its brief follows `AGENTS.md`, adds the sketch and the repo's rules that apply, and tells it to subtract before it adds: delete dead code and one-caller wrappers first, and make the smallest diff that reaches the sketch. Don't edit while it runs. Split into parallel children only when the work divides into files that don't overlap, each in its own worktree per `AGENTS.md`. Bring their commits back here with `git cherry-pick`, then remove their worktrees.

The sketch is the contract. A child that needs to deviate says so in its result rather than absorbing it. Review the full diff yourself. If the same kind of friction keeps showing up (repeated workarounds, casts or escape hatches, special cases for unrelated edge cases, callers that must know the internals), the sketch is wrong. Throw it out and go back to step 3 with what you learned, aiming for a smaller design.

Commit the implementation. Then spawn a fresh child to run `/deslop` on `<base>...HEAD` in the same checkout. It did not write the code, so it will cut what the author would keep. Review its changes like any other diff and commit them.

## 5. Prove it

Run the repo's own checks for the files you changed, then `$verify` on the surface the change affects. A failed check sends you back to step 4. A required check that could not run makes the result inconclusive. Say so, and don't report the build as done.

## 6. Check for breakage and review

Medium and Large builds run this step. Run `/blast-radius` and `/council` on `<base>...HEAD` in parallel. `/council` fixes its own findings and runs its follow-up round. Fix each confirmed blast-radius risk the same way, with the smallest fix in the case the change is for. Commit the fixes and rerun step 5.

## 7. Commit and hand off

Squash the stage commits into small ordered commits that each make sense alone. If the user is iterating on UI, leave the stage commits until they say it's done.

Open a PR only when the request asked for one or the user agrees when you offer. Fetch and rebase onto the latest base first, and rerun step 5 if the rebase touched the files you changed. Open a real PR, not a draft, so review bots run, then run `/babysit-pr`. Never merge unless the user said to.

## Large

1. **Frame.** Write what done means as a check that can pass or fail, the units of work, and which steps are hard to undo. Show it to the user. Wait only when it raises a decision only they can make, or when they asked to review it first.
2. **Harness first.** Build the check before the work, and record its result on the code as it is now, so each later result reads as before and after.
3. **Units, riskiest first.** Split the work into pieces that each land on their own. Run each through steps 3 to 5, with the design arena only for units that make a design decision, and commit each before starting the next.
4. **Log decisions.** Keep `/tmp/build/<slug>/decisions.md`. Its first line is the current state (the unit in progress, what's next, what's blocked), so a fresh session can resume from it. Below that, one line per decision with the reason and the evidence, added as each unit lands. Name the file in the reply.
5. **Finish** with step 6 on the whole branch, then the Frame check on the real product, then step 7.

## Reply

The size and why, what changed for the user, the decisions you made for them, the evidence (embed screenshots), the design picked and why, what blast-radius and review found and what you fixed, and anything still open or unverified. End with the dispatch ledger: one line per step with the model that ran it, or `in-thread` or `skipped` with the reason.
