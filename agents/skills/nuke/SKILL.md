---
name: nuke
description: "Deep adversarial multi-lens code review (simplicity, correctness, scalability, boundaries, idiomatic fit) with cross-lens validation of proposed fixes. Heavier than /roast.\nTRIGGER when: the user explicitly asks for /nuke, nuke, deep-roast, or a thorough multi-lens review.\nDO NOT TRIGGER when: the user asks for a quick review, roast, critique, or sanity-check — use /roast instead."
---

# Nuke: Multi-Perspective Adversarial Review

Run a deep code review by evaluating the diff through five adversarial perspectives sequentially, then synthesize a unified verdict — not a concatenation, an actual judgment.

## Determining the Scope

Parse the user's request to determine what to analyze:

| User says | Scope |
|-----------|-------|
| `/nuke` (no args) | `git diff main...HEAD` — all changes on current branch |
| `/nuke last commit` | `git diff HEAD~1..HEAD` |
| `/nuke <file>` | Changes to that specific file on current branch |
| `/nuke staged` | `git diff --cached` |
| `/nuke <commit-ref>` | `git show <commit-ref>` |
| `/nuke spec` | The spec/plan document in the current directory (e.g. `spec.md`) |
| `/nuke spec <path>` | The spec/plan at that path |

## Process

### 1. Load context

**For a code diff:**
- Run `git status --short` first — if there's uncommitted or untracked work, flag it to the user (it won't be reviewed unless they switch scope to `/nuke staged` or `/nuke <file>`)
- Get the diff based on scope determined above
- For each changed file, read the file in full — not just the hunks
- For each changed file, skim 1–3 neighbors that show how this codebase does similar things (similar modules, sibling files, parallel implementations)

**For a spec/plan:**
- Read the document in full
- Skim 1–3 neighbors: precedent designs (similar past specs/RFCs) and the codebase areas the design will touch

**Always:**
- State the user's intent in one sentence: what problem is this solving, under what constraints?

### 2. Run five perspectives — sequentially, not interleaved

For each perspective: fully commit to its lens before moving on. Each perspective is an **adversary** that actively tries to disprove the change in its lens. Don't be balanced; don't soften. **But only keep findings backed by concrete evidence, a plausible failure mode, and a better alternative** — a manufactured finding is worse than no finding. If a perspective genuinely finds nothing, say so explicitly.

Record each finding as:
- **Severity** — P0/P1/P2/P3, per the rubric in each perspective
- **Claim** — what's wrong
- **Evidence** — `file:line` + a short quote
- **Fix** — concrete alternative (code snippet if non-trivial)

**If you're reviewing a spec/plan**, read each perspective's hunt list through this translation:

| Lens | Spec/plan framing |
|---|---|
| Simplicity / Code-judo | what scope/phase/feature can be cut? |
| Correctness / Gaps | what scenarios does this design not cover? what assumptions are hidden? |
| Scalability / Blast radius | what load model does this assume? when does it break? |
| Boundaries / Canonical layers | ownership/team boundaries; reinventing an existing system |
| Idiomatic fit | does this match how the org/codebase usually solves this kind of problem? |

Severity rubrics and verdict labels still apply. For spec mode: **SHIP** = ready to implement; **REVISE** = address before implementing; **REDESIGN** = fundamental rework.

**Lens boundaries** — to avoid duplicate findings across perspectives:

| Concern | Owned by |
|---|---|
| Edge cases, error handling, race conditions | Correctness |
| Load behavior, capacity failures | Scalability |
| Code placement, module ownership, duplicated helpers | Boundaries |
| Naming, style, convention drift | Idiomatic |
| Deletion / structural-simplification opportunities | Simplicity |

If you spot something during one perspective that belongs to another, note it briefly and defer the depth analysis to the owning lens.

---

#### Perspective 1 — Simplicity / Code-judo

**Voice:** A minimalist who believes the best code is the code that doesn't exist.

**Hunt:** abstractions with a single use site; helpers whose name adds no information beyond the body; custom code reimplementing stdlib/framework features; defensive checks for impossible conditions; intermediate variables that just route data through; branching that disappears if you reshape the data; backwards-compat shims for unreleased code.

**Severity:**
- **P0** — structurally dead branch on day one
- **P1** — 50+ lines that collapse to 10 with a known idiom
- **P2** — verbose-but-correct where a local idiom exists
- **P3** — single inline-able variable

**Owe:** the deletion or the smaller alternative, written out. "This could be simpler" without the simpler version is a vibe, not a finding.

---

#### Perspective 2 — Correctness / Gaps

**Voice:** A paranoid SRE on call. The happy path is irrelevant; you only care about the 3 AM page.

**Hunt:** edge cases (empty/nil/zero, single-element, max-size, concurrent callers); swallowed errors and partial-failure states; off-by-one and range bounds; ordering assumptions across async boundaries; trust-boundary inputs not validated; resource lifecycle leaks (files, connections, locks); implicit assumptions about timezone/locale/ordering/non-emptiness.

**Severity:**
- **P0** — silent data corruption, security implications, deadlock under realistic load
- **P1** — crash on plausible input; error swallowed where the caller needs to know
- **P2** — edge case that would surprise a user but recovers cleanly
- **P3** — defensive guard that's missing but never actually hit in practice

**Owe:** the input or sequence that triggers the bug, plus the fix. If you can't name the trigger, it's hypothetical — P2/P3 at most.

---

#### Perspective 3 — Scalability / Blast radius

**Voice:** A staff engineer who's been personally paged for every kind of capacity failure.

**Hunt:** N+1 queries (loop body fetches per-iteration); unbounded inputs (missing pagination, user-controlled depth or size); hot-path per-request allocations; sync I/O blocking what should be concurrent; caches without invalidation or with stampede risk; locks held across I/O or with inconsistent ordering; per-record logs/metrics on hot paths; one slow caller starving the system (no isolation, no circuit-breaking).

**Severity:**
- **P0** — will fall over at *current* production load if shipped
- **P1** — will fall over at expected next-year load, or fix is structural and gets harder over time
- **P2** — inefficient but no near-term threat
- **P3** — negligible at any realistic scale

**Owe:** the load condition that triggers the problem, plus the structural change. "Could be faster" without a load model is a vibe.

---

#### Perspective 4 — Boundaries / Canonical layers

**Voice:** The architect who has watched logic drift into the wrong layers for years and now reflexively asks "where does this belong?"

**Hunt:** logic in transport/presentation that belongs in domain (or vice versa); domain logic reaching into infrastructure-specific shapes; helpers added where convenient, not where owned; **duplicated helpers** — same operation reinvented in two places (grep the repo before flagging); new public API surface without a real second consumer; modules importing siblings' internals; abstractions that don't carve at the domain's joints (one type covering two concepts, or two types where one would do).

**Severity:**
- **P0** — new structural dependency cycle, or violates a documented architectural rule
- **P1** — logic in a layer where it will cost real refactor to move later
- **P2** — wrong place but cheap to relocate
- **P3** — mild misplacement, defensible either way

**Owe:** the correct location *plus* a citation in the codebase if a sibling already exists. Naming the canonical pattern is gold.

---

#### Perspective 5 — Idiomatic fit

**Voice:** A long-time committer in this codebase who can spot AI-written code from across the room. Not pedantic about style — protecting the codebase's coherence.

**Hunt:** naming patterns that diverge from neighbors; test/mocking/fixture style that diverges; error model that diverges (Result vs throws, custom errors vs stdlib); file structure or module layout drift; new utilities when a local equivalent exists; AI-slop comments explaining obvious code; defensive style foreign to this codebase; `any`/`@ts-ignore` (or language equivalent) where the team has strict-mode discipline.

**Severity:**
- **P0** — bypasses a documented project rule (linter suppression, strict-mode escape)
- **P1** — significant divergence (different error model, different test style) that will compound
- **P2** — local divergence that should conform but isn't load-bearing
- **P3** — one-off style nit

**Owe:** a pointer to the canonical example. "Naming is off" without "see `foo/bar.ts:42` for how this is usually done here" is a vibe.

---

### 3. Synthesize — unify the findings, don't concatenate

Do not produce one section per lens.

1. **Dedupe.** Many findings will overlap (a simplicity issue is often also an idiomatic-fit issue). Merge them; keep the strongest framing.
2. **Surface cross-lens issues.** Findings that span multiple perspectives are usually the most important. Example: "this new helper duplicates an existing one (boundaries), is harder to test (correctness), and hides the actual logic (simplicity)." That's *one* finding tagged with three lenses, not three findings.
3. **Rank** by severity first, then by leverage — prefer fixes that improve multiple lenses.

You should now have a candidate findings list. The verdict is not yet stated — that's step 4.

### 4. Validate — pressure-test fixes across lenses

For each P0/P1 finding, mentally apply the proposed fix and check whether it creates issues in *other* lenses. Three outcomes per finding:

- **Clean** — the fix doesn't trip any other lens. Keep the finding as-is.
- **Tradeoff** — the fix improves the original lens but creates a smaller issue elsewhere. Document both costs inside the finding; let the user weigh.
- **Tension** — two findings want fixes that genuinely conflict (e.g. Simplicity wants to delete the check, Correctness wants it stronger). Merge them into a single **Tension** entry that frames the conflict and presents both options. Do not present them as two contradictory findings.

After validation, state the verdict:

- **SHIP** — no P0/P1 findings and no unresolved Tensions; minor concerns documented but not blocking
- **REVISE** — has P1s or Tensions that should be addressed before merging
- **REDESIGN** — has P0s, or structural concerns deep enough that incremental fixes won't help

### 5. Iteration

If the user pushes back on a finding:
- Hear the defense
- Re-evaluate *only the relevant perspective(s)* — don't re-run all five
- Either accept the defense and downgrade/remove the finding, or hold the line with a specific rebuttal
- Update the verdict if affected

Cap at 2 rounds. Remaining disagreement after that is a judgment call, not a review issue.

## Output

Structure the final response as:

### Verdict: [SHIP | REVISE | REDESIGN]

**Intent:** <one sentence — how you understood the change>

**Findings (ranked):**

**[P0] <claim>** — `file:line`
  Evidence: <quote>
  Why it matters: <one line>
  Fix: <snippet or short description>
  Lenses: simplicity, correctness

**[P1] ...**

...

*The following sections are optional — include only when applicable:*

**Tensions (need your call):**

**[T1] <one-line framing of the conflict>** — `file:line`
  Option A: <fix from lens X>
  Option B: <fix from lens Y>
  Tradeoff: <what each costs>

**Strengths:** <genuine strengths only — omit if none are worth naming>

**Clean lenses:** <list any lens that genuinely found nothing — omit if all lenses found findings>

---

Be direct. The goal is to catch issues, not to be balanced. Praise is fine only when it identifies a specific choice worth preserving against future churn.
