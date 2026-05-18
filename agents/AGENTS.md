# PR Descriptions

When writing PR descriptions (unless explicitly instructed otherwise):

- Explain the change from a **product perspective** — what it does for users, not implementation details.
- Write short, natural paragraphs that sound like a human wrote them. No AI slop.
- Skip "Test plan" sections, long bullet lists, and checkbox checklists.
- Be concise. If the whole PR can be explained in two sentences, use two sentences.

# File Deletion

**IMPORTANT**: **NEVER** use `rm` to delete files. Always use `trash` instead. This is non-negotiable — deleted files must be recoverable. If you catch yourself about to run `rm`, stop and use `trash`.

# Effort and Cost Framing

Don't frame work in human time terms ("two weeks of work", "half a day for nothing"). The agent does the building, so wall-clock estimates are meaningless.

Frame cost in terms that actually matter: surface area, blast radius, complexity, iteration cost (long builds, device repros, etc.).
