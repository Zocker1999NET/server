---
name: commit-changed
description: Analyze changed files (ignoring untracked), suggest a commit message based on previous commits, and commit the changes.
---

## Purpose
Automate the process of analyzing currently changed files (ignoring untracked ones), selecting an appropriate commit message based on previous commit messages for the same files, and committing the changes.

## Prompt Template

**Task:**
- Analyze the currently changed files in the repository, but ignore untracked files (only consider staged and unstaged tracked files).
- For each changed file, retrieve the first line of previous commit messages that affected it.
- Based on the patterns and wording of those previous commit messages, select or synthesize an appropriate, concise commit message for the current changes.
- Commit the changes with the selected message.

**Inputs:**
- The current git status (to determine which files are changed and which are untracked).
- The git log for each changed file (to extract previous commit messages).

**Output:**
- The repository is committed with a message that matches the style and content of previous commits for the affected files.
- If no previous commits exist for a file, generate a clear, descriptive message based on the filename and type of change.

**Notes:**
- Do not include untracked files in the commit.
- Prefer concise, file-specific messages if only one file is changed; otherwise, summarize the change across files.
- If multiple files are changed, and their previous commit messages share a prefix or style, use that as a template.
- If unsure, ask the user for clarification before committing.

---

## Example Commit Message Patterns
- `vscode: set git.countBadge to tracked`
- `vscode: remove roo-cline.allowedCommands as extension removed`
- `home-develop: add code spell checker extensions`

---

## Related Customizations
- Prompt for staging untracked files before committing, if desired.
- Optionally allow the user to edit the generated commit message before finalizing.
