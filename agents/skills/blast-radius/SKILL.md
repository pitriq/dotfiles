---
name: blast-radius
description: "Find what a change could break outside its own diff, and prove the one fact it is safe because of by running real code instead of writing it up. For a diff you don't trust yet, or one that touches shared code, data, or formats.\nTRIGGER when the user invokes /blast-radius or asks 'what could this break' or for the blast radius of a change, and when /build calls for it."
---

# Blast radius

Find what a change breaks somewhere else, before it ships. Listing the callers is not the job, because grep does that in a second. The job is the breakage grep won't show.

A writeup that sounds right is worthless, because it reads as convincing whether or not it is true. Find the one or two facts the change's safety depends on and prove them by running code.

## How sure are you

Take each fact as far down this list as is cheap, and say where it stopped:

1. You said so. Worthless on its own.
2. You pointed at the line: a real `file:line`, or the library's own source.
3. You walked the failure step by step and showed it can't happen.
4. You ran it: a script or test that calls the real code and fails loudly if you are wrong.
5. You reproduced it in the running app with `$verify`.

Step 4 is usually one small script that imports the library the app ships and calls the exact function you are worried about.

## Steps

1. **Read the change.** The diff, the symbols it adds, changes, and deletes, and what it now does differently, including what the diff doesn't spell out. Read the PR and commit messages when there are any.
2. **Find the one fact it's safe because of.** Most risky-looking changes are safe because of one fact, such as "this call only drops cache entries that are already dead". If it holds, most risks clear at once. Spend your time here, not on a long list of maybes.
3. **Look where grep stops.** Read the source of the libraries you call, at the pinned version and with any local patch. Work out when things run: microtasks, teardown, render order. Follow what a symbol search misses: JSON an API returns, a database column, a wire format, another language reading the same bytes, a feature flag, code three hops downstream.
4. **Be honest about each risk.** Give it a real chance and a real cost. Keep the confirmed ones, and list the ones you checked and cleared separately. Cite real `file:line`. A search that finds nothing is still an answer, and never invent a caller or an API.
5. **Prove the one fact.** Write a script or test that runs the real code, run it, and paste what happened.

## Reply

- **What it does,** including the part that isn't obvious.
- **The fact it's safe because of,** the step you got it to, and the proof, or "unproven".
- **Risks:** how each breaks, `file:line`, how likely and how bad, and how to check. Paste the proof for the ones that matter.
- **Cleared:** what you checked and why it's fine.
- **Before you merge:** the cheapest test or repro that catches the real bug, including the script you wrote.
