---
name: design
description: Gather requirements and create a specification for a new feature or system. Use when the user wants to design, spec out, or plan requirements for something they want to build.
---

# Design Skill

Help the user flesh out their idea into a complete specification.

## Process

1. **Listen** to the user's problem or idea description
2. **Ask clarifying questions** using the `AskUserQuestion` tool when there are genuine ambiguities or gaps that would affect implementation:
   - Unclear scope or boundaries
   - Missing edge cases that could cause issues
   - Integration points with existing systems
   - Constraints (performance, security, compatibility)
   - User-facing behavior that needs definition
3. **Stop asking** when you have enough to write a useful spec - don't over-question
4. **Generate** a spec.md file using the template in [spec-template.md](spec-template.md)

## Guidelines

- **Always use the `AskUserQuestion` tool** for clarifying questions - this provides a better UX with selectable options
- You can ask up to 4 questions at once, each with 2-4 options
- Write concise option labels (1-5 words) with helpful descriptions
- Use `multiSelect: true` when choices aren't mutually exclusive
- Users can always select "Other" to provide custom input
- Group related questions in a single tool call when possible
- Accept "Other" responses gracefully and follow up if needed
- Use your judgment - simple features need fewer questions
- Explore the codebase if needed to understand existing patterns and constraints
- The spec should be actionable for implementation planning

## Output

Save the final specification to `spec.md` in the current working directory (or project root if appropriate).

After creating the spec, suggest the user review it and then use plan mode to create an implementation plan.
