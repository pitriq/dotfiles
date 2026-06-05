---
name: teachback
description: "Guide the user to deeply understand the current session, current code changes, or a named area of the codebase through incremental explanation, a running checklist, user restatement, and quizzes.\nTRIGGER when: the user invokes /teachback, asks to understand the current session/current changes, asks for a guided walkthrough, or asks to understand a specific module, feature, diff, bug, or implementation.\nDefault with no explicit target: teach the current session and current branch changes."
---

# Teachback Skill

Help the user understand the work, not just receive a summary. Optimize for durable understanding of the problem, solution, rationale, edge cases, and impact.

## Scope

Determine the teaching target from the request:

| User says | Scope |
|-----------|-------|
| `/teachback` | Current conversation plus current branch changes, usually `git diff main...HEAD` when in a repo |
| `/teachback current changes` | Current branch changes |
| `/teachback last commit` | `git show HEAD` |
| `/teachback <file/module/feature>` | That code area and its relevant surrounding context |
| `/teachback <bug/spec/PR>` | That artifact plus affected implementation context |

If the target is unclear, make a reasonable narrow assumption and say what you chose. Ask a question only when the ambiguity would materially change what must be taught.

## Running Checklist

Create or update `teachback.md` in the current project root. Keep it concise and current.

The document should include:

- Teaching target and date
- What the user should understand
- Checklist grouped by:
  - Problem: what happened, why it existed, branches/paths/cases involved
  - Solution: what changed, why this approach, important design decisions
  - Edge cases: failure modes, boundaries, regressions, surprising cases
  - Impact: user/product effect, systems touched, operational or maintenance implications
- Mastery status:
  - `Not started`
  - `Explained`
  - `User restated`
  - `Verified`
- Open questions and remaining gaps

Update the document after each stage instead of only at the end.

## Teaching Loop

Work incrementally. Do not dump the entire explanation at once.

1. **Inspect enough context**
   - Read the relevant conversation, diff, files, tests, docs, or runtime behavior.
   - For code, read surrounding implementation context before teaching the change.

2. **Build the checklist**
   - Identify the small set of concepts the user must understand.
   - Include both high-level motivation and low-level business logic.
   - Include the "why" chain: why the problem existed, why this solution works, why alternatives were not chosen.
   - If a goal-tracking mechanism is available and permitted, set the success condition to verifying that the user understands every required checklist item. Otherwise, enforce that condition behaviorally in the conversation.

3. **Start with teachback**
   - Ask the user to restate their current understanding before explaining deeply.
   - Use their answer to decide what to explain first.

4. **Teach one stage**
   - Explain only the current checklist group.
   - Prefer concrete code references, examples, traces, or debugger steps when useful.
   - Adjust depth on request:
     - `ELI5`: intuitive, minimal jargon
     - `ELI14`: accurate but simplified
     - `ELII`: explain like an intern joining the project

5. **Verify before moving on**
   - Ask the user to restate the current stage in their own words.
   - Quiz with open-ended or multiple-choice questions.
   - Use the available structured user-question tool when present; otherwise ask directly.
   - Change the position/order of correct multiple-choice answers across quizzes.
   - Do not reveal answers until after the user responds.

6. **Fill gaps**
   - Correct misunderstandings directly and kindly.
   - Drill into additional "why" questions when the user's answer is shallow.
   - Mark checklist items as verified only after the user demonstrates understanding.

7. **Continue or finish**
   - Move to the next stage only after the current one is verified.
   - Do not present the session as complete until every required checklist item is verified.
   - If the user chooses to stop early, update `teachback.md` with remaining gaps and say what remains unverified.

## Quality Bar

- Teach the problem before the solution.
- Prefer "why" over chronology.
- Keep each stage small enough for the user to restate accurately.
- Use code, debugger steps, tests, or diagrams only when they clarify the concept.
- Avoid trivia quizzes; test causal understanding and ability to reason through edge cases.
- Be willing to slow down. The goal is demonstrated understanding, not a polished lecture.
