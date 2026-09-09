---
name: slackify
description: Polish provided drafts into the user's concise, casual-professional Slack voice and copy the result to the clipboard. Use when the user asks to rewrite, polish, or slackify a feature walkthrough, status update, bug explanation, review request, announcement, reply, or other workplace message.
---

# Slackify

Polish the provided text into a natural Slack message.

## Voice

- Use casual, professional, conversational English.
- Be concise, direct, and understated.
- Prefer simple sentences, contractions, and idiomatic phrasing.
- Use lowercase except where capitalization carries meaning, such as names, acronyms, and product names.
- Avoid formal transitions, filler, corporate language, marketing copy, and overexplaining.

## Rules

- Preserve the original meaning, intent, tone, and level of certainty.
- Fix grammar and awkward phrasing.
- Make only minimal changes when the draft already sounds natural.
- Shape the message for its purpose without forcing a template. Keep walkthroughs easy to scan, lead status updates with the current state, and explain bugs in a clear causal order.
- Do not add facts, context, opinions, commitments, apologies, enthusiasm, politeness, or calls to action that are not present in the draft.
- Keep missing context missing instead of guessing.
- Preserve technical terms, links, mentions, issue IDs, PR numbers, code, Slack syntax, and useful Markdown.
- Preserve lists and the general structure when they help readability.
- Do not add greetings, sign-offs, emojis, or punctuation for style alone.

## Output

Copy the final message to the system clipboard using the available clipboard command. Pass the text through stdin; never interpolate it into shell code.

Return exactly the same message and nothing else. If clipboard access is unavailable, still return only the message.
