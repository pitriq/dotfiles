---
name: arena
description: "Give the same brief to several models in parallel, have a judge from another model family score the results, then pick the best and fold in what the others did better. Works for code, plans, prompts, names, or a second opinion on an approach.\nTRIGGER when the user invokes /arena or says 'arena this' or 'throw it in the arena', and when /build calls for a design arena. Do not trigger for ordinary implementation or review requests."
---

# Arena

One attempt locks in the first shape a model thinks of. Arena runs several attempts at the same brief and keeps the best parts.

## 1. Write the brief

Every candidate gets the same brief, so the brief is the contract. Candidates do not see this conversation, so make it self-contained: the goal, the constraints, the relevant context and absolute paths, and what to hand back. For "a second opinion on our approach", summarize the thread, the approach, and the open question. When the user says "verbatim", pass their prompt unchanged, with only the context it needs to make sense.

Write a rubric of 3 to 6 criteria that a good result meets for this task. The judge uses it. Candidates never see it.

## 2. Run the candidates

Spawn one candidate on `claudeAgent/claude-opus-5-5` with `effort=xhigh` and one on `codex/gpt-6.1-sol` with `reasoningEffort=xhigh`, both in one message, with `mode: "async"`. Use more seats, or the same model several times, only when the user asks. When the user says "compare with yours", write your own answer before reading theirs and enter it as one more candidate.

A candidate that writes code gets its own worktree with dependencies only, per `AGENTS.md`, and commits its work on that worktree's branch. Every other candidate is told to change no file and to return its answer in its result. Each candidate also names the strongest alternative it rejected and why.

If a candidate fails, continue with the rest and name it in the reply. If only one is left, there is nothing to compare, so say so and treat it as a draft for your own review.

## 3. Judge

When every candidate is done, spawn the judge as a fresh child on `codex/gpt-6-astra` with `reasoningEffort=xhigh`. It ran no candidate, so it isn't scoring its own work. If it can't run, use a model that ran no candidate, else one from a different family than yours, and say which. The judge changes no file, sees the rubric and the candidates labeled A, B, C without model names, scores each criterion, and recommends a base.

Read every candidate in full yourself while the judge runs, and score them against the rubric.

## 4. Pick and merge

Pick a base. Agreement between you and the judge confirms it. If you disagree, read both reasons before deciding. Then take the one or two things each other candidate did better and fold them into the base by hand, so the result reads as one piece. If the candidates converged, say so and skip the merge, because convergence is the strongest signal arena gives. If they diverged wildly, the brief was underspecified. Fix the brief and rerun instead of averaging.

For code, merge in the current checkout: cherry-pick or reapply the base, then graft. Prove the result with `$verify`, then remove the candidate worktrees.

## Reply

The result, the base and why, what came from each other candidate, the judge's scores, and anything the candidates agreed on or split over. For a plan or text, include the result itself. For code, show the diff summary and the verification evidence.
