---
name: handoff
description: Create a comprehensive handoff document capturing the current task context, problem/feature details, progress, and next steps for seamless continuation by another agent or future session.
---

# Handoff Skill

Create a handoff document that captures everything needed to continue the current task.

## Process

1. **Analyze the conversation** to extract:
   - The problem being solved or feature being added
   - Technical context discovered during exploration
   - Key decisions and their rationale

2. **Document the work**:
   - Files modified, created, or deleted
   - Errors encountered and how they were resolved
   - What's done vs what remains

3. **Generate** `handoff.md` using [handoff-template.md](handoff-template.md)

## Guidelines

- Only include sections that have meaningful content
- Use exact file paths with line numbers
- Include code snippets only for complex patterns or non-obvious changes
- Be concise - the goal is quick context transfer, not documentation

## Output

Save to `handoff.md` in the current working directory.
