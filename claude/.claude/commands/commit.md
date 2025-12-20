---
allowed-tools: Bash(git commit:*), Bash(git status:*), Bash(git diff:*), Bash(git branch), Bash(git switch:*), Bash(git show:*), Bash(git log:*)
description: Create a conventional commit message and commit after user confirmation
---

## Context
- Current branch: !`git branch --show-current`
- Current git status: !`git status`
- Current git diff (only staged changes): !`git diff --staged`

## Execution steps
1. If the current branch it's the main branch, confirm with the user before proceeding.
  - If the user confirms, proceed with the commit process.
  - If the user denies, suggest a branch name and confirm with the user the creation of it (`git switch -c <branch_name>`)
2. If there are untracked files, ask the user to add them first
  - Only the user can add untracked files
3. If the tracked files has modifications that were not added, ask the user if he wants to add them
4. Review the current changes
5. Create the commit message and show it to the user to confirm
  - Get the difference between the current state and the previous commit
  - If context is provided (context: $ARGUMENTS), use it together with the difference to generate a commit message
  - Ensure the commit message follows the conventional commit format
  - Do not add co-authors to the commit message
6. If the user confirms the commit message, create the commit

## Notes
- Make sure the commit message is clear and concise
- If you need access to additional tools, ask the user to modify the command to include them
