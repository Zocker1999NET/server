---
name: commit-add
description: Commit only the currently opened and focused file, which is always untracked. Do not stage or commit any other files or changes.
---

## Purpose
Commit only the currently opened and focused file, which is always untracked. If there is a single-line unstaged diff in a tracked file that directly imports or references this file (e.g., `import ./commit-add.prompt.md`, `./commit-add.prompt.md`, etc.), include that change too. Do NOT stage or commit other references, such as usages of options, functions, or indirect mentions.

**Task:**
- Stage (add) only the focused, untracked file.
- If there is a one-line unstaged diff in a tracked file that directly imports or references the focused file (e.g., `import ./file`, `./file`, etc.), stage that change as well.
- Do NOT stage or commit other references, such as usages of options, functions, or indirect mentions.
- Commit with a concise message based on the filename.

## Hint
Perform actions one-by-one: stage only the focused file, and if present, at most one direct one-line import/reference change. Do not run large shell blobs.
