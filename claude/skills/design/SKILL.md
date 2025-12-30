---
name: design
description: Gather requirements and create a specification for a new feature or system. Use when the user wants to design, spec out, or plan requirements for something they want to build.
---

# Design Skill

Help the user flesh out their idea into a complete specification.

## Process

1. **Listen** to the user's problem or idea description
2. **Ask clarifying questions** only when there are genuine ambiguities or gaps that would affect implementation:
   - Unclear scope or boundaries
   - Missing edge cases that could cause issues
   - Integration points with existing systems
   - Constraints (performance, security, compatibility)
   - User-facing behavior that needs definition
3. **Stop asking** when you have enough to write a useful spec - don't over-question
4. **Generate** a spec.md file using the template in [spec-template.md](spec-template.md)

## Guidelines

- Be conversational, not interrogative
- Group related questions together
- Accept "I don't know yet" or "doesn't matter" as valid answers
- Use your judgment - simple features need fewer questions
- Explore the codebase if needed to understand existing patterns and constraints
- The spec should be actionable for implementation planning

## Output

Save the final specification to `spec.md` in the current working directory (or project root if appropriate).

After creating the spec, suggest the user review it and then use plan mode to create an implementation plan.
