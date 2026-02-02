---
name: roast
description: Critically analyze code changes to verify they're optimal, elegant, and correct. Challenges assumptions and proves the solution is the best approach for the problem.
---

# Roast My Changes

Grill the user on their changes. With full context of the implementation or having seen it implemented, critically evaluate whether this is the most elegant, efficient, and correct solution.

## Determining the Scope

Parse the user's request to determine what to analyze:

| User says | Scope |
|-----------|-------|
| `/roast` (no args) | `git diff main...HEAD` - all changes on current branch |
| `/roast last commit` | `git diff HEAD~1` |
| `/roast <file>` | Changes to that specific file on current branch |
| `/roast staged` | `git diff --cached` |
| `/roast <commit-ref>` | `git show <commit-ref>` |

## Process

1. **Get the diff** based on scope determined above

2. **Read the full context** - For each modified file, read the entire file to understand:
   - The broader system architecture
   - Existing patterns and conventions
   - How this code integrates with the rest

3. **Understand the intent** - What problem is this solving? What were the constraints?

4. **Challenge everything:**

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

5. **Prove or disprove** - For each concern:
   - If the current approach is correct, explain *why* it's the right choice
   - If there's a better approach, show concrete alternative code
   - Don't just say "this could be better" - demonstrate it

## Output

Structure your response as:

### Verdict: [SOLID | COULD BE BETTER | NEEDS WORK]

**What it does right:**
- List genuine strengths (not filler praise)

**Concerns:**
For each issue found:
- What the problem is
- Why it matters
- Concrete fix (show code if non-trivial)

**Alternative approaches considered:**
- If there were other valid ways to solve this, briefly explain why the chosen approach is or isn't the best

---

Be direct and specific. The goal is to catch issues before they ship and to build confidence that the solution is sound. Don't soften criticism - if something is wrong, say so clearly.
