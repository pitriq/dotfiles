---
name: council
description: "Review a change on three models from different providers with the /vet method, merge their findings, fix the real ones without growing the change, and run one follow-up round on the fixes.\nTRIGGER when the user invokes /council or asks for a council or multi-model review, and when /build calls for it."
---

# Council

Three models review the same change with `vet`, and you stay the lead. Different models miss different bugs, so a finding that two of them raise on their own is the strongest signal this review gives.

## 1. Scope and intent

Take the scope the caller gives. Otherwise review `git diff <base>...HEAD`, where `<base>` is `origin/<default branch>` after `git fetch origin`. Commit uncommitted work first, or name it in the brief, so every seat reviews the same thing. Read the change yourself and state its intent and what is out of scope in one or two sentences.

## 2. Convene

Spawn one reviewer on each of these, all in one message, with `role: "review"` and `mode: "async"` in T3:

- `claudeAgent/claude-opus-5-5` with `effort=xhigh`
- `claudeAgent/claude-fable-5-1` with `effort=xhigh`
- `codex/gpt-6.1-sol` with `reasoningEffort=xhigh`

Each brief names the absolute path of `../vet/SKILL.md` from this file, the repo's absolute path, the scope command, the intent and out-of-scope line, and which checks ran or could not run. It tells the reviewer to change no file, commit nothing, start no subagents, run steps 1 to 3 of `vet`, and return its ranked findings in that file's format, without a verdict. Don't edit the reviewed files while they run.

Outside T3, follow the fallback in `AGENTS.md` and name the seats you skipped. If no seat can run, say so and run `/vet` yourself.

## 3. Merge and check

The same issue from several seats is one finding. Check every finding you keep against the code yourself, including ones every seat raised, and note which seats raised it. Then run `vet`'s step 4 on the merged list and give its verdict.

## 4. Fix without growing the change

Review loops grow a change one cheap-looking fix at a time. Fix real bugs in the case the change is for, with the smallest fix, and prefer one that deletes or narrows code. Another path, a rare case, a small cost, or a guard or test the intent doesn't need is a nit, whatever severity it came with: decline it in one line with the reason and list it as a follow-up. When a finding is wrong, say why with evidence (`file:line`, a test, output).

Rerun the checks after the fixes. If the fixes grew the diff, cut first.

## 5. One follow-up round

If the fixes changed behavior, spawn a fresh round on the seats whose findings you fixed or disputed. The brief is the first round's brief, the ledger (each finding as fixed, disputed with evidence, or declined), and the diff since the first round. They check only the open findings and the changed code, and mark each finding resolved or still open with the reason.

Stop after two rounds. A finding still disputed after that goes to the user, with both sides in two or three lines each. A seat that times out or doesn't reply has not approved anything.

## Reply

The verdict, the findings with `Seen by:` and the seats that raised each, what you fixed, what you declined and why, how many rounds ran and on which seats, and anything still disputed.
