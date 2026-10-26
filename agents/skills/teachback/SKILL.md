---
name: teachback
description: "Teach the user a change or feature before they ship it: a layered walkthrough page that ends in a self-grading quiz, shown inline in T3 Code or opened in the browser.\nTRIGGER ONLY when the user explicitly invokes /teachback or says teachback, or asks to be quizzed on their understanding. Do not trigger for ordinary requests to explain, summarize, or walk through something. Default target: this conversation plus the current branch's changes."
---

# Teachback

Help the user understand a change well enough to own it: the problem, the solution and why, the edge cases, and the impact. Build one page they read at their own pace, with depth on demand, ending in a quiz that tests reasoning.

## 1. Pick the target

| User says | Target |
|---|---|
| `/teachback` | This conversation plus the branch's changes, `git diff origin/<default branch>...HEAD` |
| `/teachback last commit` | `git show HEAD` |
| `/teachback <file, module, or feature>` | That code and the code around it |
| `/teachback <bug, spec, or PR>` | That artifact plus the code it touches |

If the target is unclear, pick the narrowest reasonable one and say which.

## 2. Read it

Read the diff, the code around it, the tests, and this conversation, where the reasons behind decisions live. Note what the user already discussed here. Cover that lightly and spend the depth on what they haven't seen.

## 3. Write the walkthrough

Copy `template.html` next to this file and fill it. Keep its four layers in order: Problem, Solution, Edge cases, Impact.

- Each layer opens with two or three sentences that stand alone. Its "Go deeper" block holds the why chain, the alternatives that were rejected and why, and the code that carries it.
- Use three to six short code excerpts across the page, each under its `file:line`.
- Add one flow (the `.flow` steps, or inline SVG) where it makes a sequence or a before-and-after clearer.
- Teach the problem before the solution, and prefer why over chronology. Cut anything that doesn't help the user own the change.

## 4. Write the quiz

Fill the `quiz-data` block with five to eight multiple-choice questions, each tagged with its layer, covering every layer. Ask about causes and consequences ("what happens if this runs twice", "why doesn't this break X"), not names or trivia. Make the wrong options the mistakes a smart reader would make. Every option gets a one-line `why`. The template shuffles the options and scores by layer.

Add one or two open questions with a model answer, on the ideas that matter most. The user writes their answer, then reveals yours.

## 5. Show it

In T3 Code, check the page with `html_preview` and fix any layout or console error, then show it with `html_render`, using the `contentHeight` from the preview. Elsewhere, write it to `/tmp/teachback/<slug>.html` and `open` it.

Don't restate the page in the reply. Say in one line what it covers. If the user tells you what they missed, go deeper on those layers in the thread.
