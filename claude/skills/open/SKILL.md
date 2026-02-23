---
name: open
description: Open files referenced in the conversation in Cursor using the "code" CLI alias.
---

# Open in Cursor

Open files from the conversation in Cursor using the `code` command.

## Determining Which Files to Open

Parse the user's request and the recent conversation to determine which files to open:

| User says | What to open |
|-----------|-------------|
| `/open` (no args) | All file paths mentioned in your most recent response |
| `/open <file or description>` | The file(s) matching the user's description from recent conversation context |

When the user provides a description like "the tests", "that file", "the editor file", "the config", etc., scan the recent conversation for file paths that match the description. Use your judgement to resolve references — e.g. "the tests" means test files, "that file" means the most recently discussed file.

## Process

1. **Identify files** — Collect all file paths from the relevant conversation context. These could appear as:
   - Explicit paths (e.g. `src/utils/helpers.ts`)
   - Paths in code blocks or tool results
   - Paths mentioned in grep/glob/read results
   - Line-number references like `file.ts:42` (strip the line number suffix)

2. **Resolve paths** — Ensure each path is absolute. If a path is relative, resolve it against the project root.

3. **Validate** — Check that each file exists before opening. Skip files that don't exist and mention them to the user.

4. **Open** — Run `code <file1> <file2> ...` to open all files in Cursor in a single command.

## Output

After opening, briefly list what you opened:

```
Opened in Cursor:
- path/to/file1.ts
- path/to/file2.ts
```

If some files were skipped, mention why. If no files were found, tell the user you couldn't find any file references in the recent conversation.
