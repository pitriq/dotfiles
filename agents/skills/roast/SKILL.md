---
name: roast
description: "Critically analyze code changes to verify they're optimal, elegant, and correct. Challenges assumptions and proves the solution is the best approach for the problem.\nTRIGGER when: the user asks to review, roast, critique, or sanity-check their code changes."
---

# Roast My Changes

Grill the user on their changes. With full context of the implementation or having seen it implemented, critically evaluate whether this is the most elegant, efficient, and correct solution.

## Determining the Scope

Parse the user's request to determine what to analyze:

| User says | Scope |
|-----------|-------|
| `/roast` (no args) | `git diff main...HEAD` - all changes on current branch |
| `/roast last commit` | `git diff HEAD~1..HEAD` |
| `/roast <file>` | Changes to that specific file on current branch |
| `/roast staged` | `git diff --cached` |
| `/roast <commit-ref>` | `git show <commit-ref>` |
| `/roast spec` | The spec/plan document in the current directory (e.g. `spec.md`) |
| `/roast spec <path>` | The spec/plan at that path |

## Process

1. **Get the diff** based on scope determined above

2. **Read the full context**

   **For a code diff:** read each modified file in full to understand the broader system architecture, existing patterns and conventions, and how this code integrates with the rest.

   **For a spec/plan:** read the document in full. Skim 1–2 precedent designs (similar past specs/RFCs) or the codebase areas the design will touch.

3. **Understand the intent** - What problem is this solving? What were the constraints?

4. **Challenge everything:**

   *For a spec/plan, read each area as a design-level question — Correctness → "what scenarios does this miss?"; Efficiency → "what load model is assumed?"; Design and Idiomatic translate naturally.*

   **Correctness:**
   - Does it actually solve the problem completely?
   - Are there edge cases not handled?
   - Could it fail silently or produce wrong results?

   **Design:**
   - Is this the right abstraction level?
   - Does it introduce unnecessary complexity?
   - Would a different approach be clearer or more maintainable?
   - Is there existing code/pattern that could have been reused?

   **Efficiency:**
   - Are there obvious performance issues?
   - Unnecessary iterations, allocations, or I/O?
   - Could this be done with simpler data structures?

   **Idiomatic code:**
   - Does it follow the conventions of this codebase?
   - Does it follow language/framework best practices?
   - Would an experienced developer in this stack do it this way?

5. **Tag and demonstrate** - For each concern:
   - **Tag severity:**
     - **P0** — blocks shipping (correctness failure, silent data corruption, security)
     - **P1** — should fix before shipping (likely to bite; significant design issue)
     - **P2** — consider (worth making but not blocking)
     - **P3** — nit (style, naming, minor polish)
   - **Demonstrate:** if there's a better approach, show concrete alternative code. If the current approach is right, explain *why*. "This could be better" without showing the better version is a vibe, not a finding.

## Output

Structure your response as:

### Verdict: [GOOD | MID | BAD]

**What it does right:**
- List genuine strengths (not filler praise)

**Findings (ranked):**

**[P0] <claim>** — `file:line` (if applicable)
  Why it matters: <one line>
  Fix: <concrete alternative; show code if non-trivial, or explain why the current approach is right>

**[P1] ...**

...

**Alternative approaches considered:**
- If there were other valid ways to solve this, briefly explain why the chosen approach is or isn't the best

---

Be direct and specific. The goal is to catch issues before they ship and to build confidence that the solution is sound. Don't soften criticism - if something is wrong, say so clearly.
