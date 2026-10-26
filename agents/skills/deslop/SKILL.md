---
name: deslop
description: Remove AI-generated code slop from current branch
---

# Remove AI Code Slop

Your task is to review the branch's diff and remove all AI-generated "slop" introduced in it. Use the scope the caller gives. Otherwise diff against the default branch, which is `git symbolic-ref --short refs/remotes/origin/HEAD`, else `main`.

## Process

1. Get the diff:
   ```
   git diff <default branch>...HEAD
   ```

2. For each modified file, read the full file to understand its existing style and patterns

3. Identify and remove the following types of slop:

   **Unnecessary comments:**
   - Comments explaining obvious code that a human wouldn't add
   - Comments inconsistent with the rest of the file's commenting style
   - Redundant JSDoc/docstrings when the function signature is self-explanatory

   **Defensive over-engineering:**
   - Extra try/catch blocks that are abnormal for that area of the codebase
   - Null/undefined checks on trusted internal code paths
   - Validation that duplicates what's already guaranteed by callers
   - Error handling for impossible cases

   **Type system workarounds:**
   - Casts to `any`, `unknown`, or language-equivalent dynamic types to bypass type errors
   - Type assertions that shouldn't be necessary
   - `@ts-ignore`, `# type: ignore`, or similar suppression comments

   **Leftovers from the change:**
   - Code the change made dead, and old paths it replaced but kept
   - Wrappers and helpers with a single caller that add nothing over inlining

   **Style inconsistencies:**
   - Naming conventions that differ from the rest of the file
   - Formatting or structure that doesn't match surrounding code
   - Over-abstraction or unnecessary indirection

4. Make surgical edits to remove only the slop while preserving the intended functionality

## Output

After completing all changes, provide ONLY a 1-3 sentence summary of what you changed. Be specific but concise.
